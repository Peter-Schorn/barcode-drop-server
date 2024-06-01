import Foundation
import Vapor
@preconcurrency import MongoKitten

func routes(_ app: Application) async throws {

    // MARK: Initialize Database


    let barcodesCollection = app.mongo["barcodes"]

    // let scanStreamCollection = ScanStreamCollection(
    //     collection: barcodesCollection
    // )
    // try app.register(collection: scanStreamCollection)

    let webSocketClients = WebsocketClients(eventLoop: app.eventLoopGroup.next())

    // MARK: - Change Streams -
    // let changeStream = try await barcodesCollection.watch()

    let changeStream: ChangeStream<ScannedBarcode>

        do {

            changeStream = try await barcodesCollection.buildChangeStream(
                options: { () -> MongoKitten.ChangeStreamOptions in
                    var options = ChangeStreamOptions()
                    options.fullDocument = .required
                    return options
                }(),
                ofType: ScannedBarcode.self,
                build: {
                    // Match(where: "fullDocument.user" == user)
                }
            )
            app.logger.info(
                "created app-level change stream"
            )

        } catch {
            app.logger.error(
                """
                could not create app-level change stream: \(error)
                """
            )
            return
        }

        // handle change stream notifications
        Task.detached(operation: {
            do {
                for try await notification in changeStream {
                    app.logger.info(
                        """
                        app-level change stream received notification: 
                        \(notification)
                        """
                    )

                    if 
                        let document = notification.fullDocument, 
                        let user = document.user 
                    {
                        for client in webSocketClients.active {
                            if client.user == user {

                                app.logger.info(
                                    """
                                    notification applies to user: \(user) \
                                    (client.id: \(client.id))
                                    """
                                )

                                if notification.operationType == .insert {
                                    app.logger.info(
                                        """
                                        sending insertNewScan message to user: \
                                        \(user)
                                        """
                                    )

                                    let insertNewScan = InsertNewScan(
                                        document
                                    )
                                    try await client.socket.sendJSON(
                                        insertNewScan
                                    )

                                }
                                else {
                                    app.logger.info(
                                        """
                                        RECEIVED ANOTHER OPERATION TYPE: \
                                        \(notification.operationType)
                                        """
                                    )
                                }

                            }
                        }
                    }
                }
            } catch {
                app.logger.error(
                    """
                    error handling change stream notification: \(error)
                    """
                )
            }
        })

        
    // MARK: - Routes -

    app.logger.info("setting up routes")

    // MARK: GET /
    //
    // Returns a success message with the version string.
    app.get { req async -> String in
        let message = "success (version 0.3.3)"
        req.logger.info("\(message)")
        return message
    }

    // MARK: POST /scan/<user>
    //
    // Saves scanned barcode to the database.
    // 
    // The barcode can be sent in the request body as JSON, URL encoded, or
    // in the query string. If both are present, then the request body takes 
    // precedence.
    //
    // The barcode is saved to the database along with the
    // user who scanned it and the date it was scanned.
    //
    // Request:
    //
    // JSON: { "barcode": "abc123" }
    // URL Encoded: barcode=abc123
    // Query String: ?barcode=abc123
    // 
    // Response: "user 'peter' scanned 'abc123'"
    app.post("scan", ":user") { req async throws -> String in
        do {

            let user = req.parameters.get("user")

            let scan: ScanRequestBody = try Result<ScanRequestBody, Error>{
                // first try to decode using the content type in the header or 
                // default content type
                try req.content.decode(ScanRequestBody.self)
            }
            // now, try other content types
            .flatMapErrorThrowing({ error -> ScanRequestBody in
                req.logger.debug(
                    """
                    could not decode as header-specified or default content type: \
                    (\(req.content.contentType?.description ?? "nil")):
                    \(error)
                    """
                )
                return try req.query.decode(ScanRequestBody.self)   
            })
            .flatMapErrorThrowing({ error -> ScanRequestBody in
                req.logger.debug(
                    "could not decode query for \(req.url): \(error)"
                )
                return try req.content.decode(ScanRequestBody.self, as: .json)
            })
            .flatMapErrorThrowing({ error -> ScanRequestBody in
                req.logger.debug("could not decode as JSON: \(error)")
                return try req.content.decode(ScanRequestBody.self, as: .formData)
            })
            .mapError({ error in
                req.logger.debug("could not decode as form data: \(error)")
                return error
            })
            .get()

            req.logger.info(
                "user '\(user ?? "nil")' scanned '\(scan.barcode)'"
            )
            
            let scannedBarcode = ScannedBarcode(
                _id: ObjectId(),
                barcode: scan.barcode,
                user: user,
                date: Date()  // save date barcode was scanned to the database
            )

            // insert the scanned barcode into the database
            try await barcodesCollection.insertEncoded(scannedBarcode)

            return "user '\(user ?? "nil")' scanned '\(scannedBarcode.barcode)'"

        } catch let postBarcodeError {

            req.logger.warning(
                """
                error in POST /scan/<user>: \(postBarcodeError)
                    URL: \(req.url)
                    Headers: \(req.headers)
                    Body:
                    \(req.body.string ?? "nil")
                """
            )

            throw postBarcodeError
        }
    }

    // MARK: - GET -

    // MARK: GET /scans
    //
    // Retrieves all scanned barcodes from the database.
    app.get("scans") { req async throws -> Response in

        let format = try req.query.get(
            ScansOption.self,
            at: "format"
        )

        req.logger.info(
            "retrieving scanned barcodes with format: \(format)"
        )

        let scans: [ScannedBarcode] = try await barcodesCollection
            .find()  // find all documents in the collection
            .sort(["date": -1])  // sort by date in descending order
            .decode(ScannedBarcode.self)  // decode into model type
            .drain()  // load all documents into memory
        
        let scannedBarcodesResponse = ScannedBarcodeResponse.array(scans)
        
        req.logger.info(
            """
            retrieved \(scannedBarcodesResponse.count) scanned barcodes:
            \(scannedBarcodesResponse)
            """
        )

        let response = Response()
        switch format {
            case .barcodesOnly:
                let responseString = scannedBarcodesResponse
                    .map { $0.barcode }
                    .joined(separator: "\n")
                try response.content.encode(responseString)
            case .json:
                try response.content.encode(
                    scannedBarcodesResponse,
                    using: JSONEncoder.sortedKeysPrettyPrinted
                )
        }

        return response

    }

    // MARK: GET /scans/:user
    //
    // TODO: document format option
    // Retrieves scanned barcodes for a user from the database.
    app.get("scans", ":user") { req async throws -> Response in

        let user = req.parameters.get("user")

        let format = try req.query.get(
            ScansOption.self,
            at: "format"
        )

        // let format = ScansOption.json

        req.logger.info(
            """
            retrieving scanned barcodes for user \(user ?? "nil") with format: \
            \(format)
            """
        )

        let scans: [ScannedBarcode] = try await barcodesCollection
            .find("user" == user)  // find all documents for the user
            .sort(["date": -1])  // sort by date in descending order
            .decode(ScannedBarcode.self)  // decode into model type
            .drain()  // load all documents into memory
        
        let scannedBarcodesResponse = ScannedBarcodeResponse.array(scans)
        
        req.logger.info(
            """
            retrieved \(scannedBarcodesResponse.count) \
            scanned barcodes for user \(user ?? "nil"):
            \(scannedBarcodesResponse)
            """
        )

        // return scannedBarcodesResponse
        
        let response = Response()
        switch format {
            case .barcodesOnly:
                let responseString = scannedBarcodesResponse
                    .map { $0.barcode }
                    .joined(separator: "\n")
                try response.content.encode(responseString)
            case .json:
                try response.content.encode(
                    scannedBarcodesResponse,
                    using: JSONEncoder.sortedKeysPrettyPrinted
                )
        }

        return response

    }

    // MARK: GET /scans/:user/latest
    //
    // Retrieves the last scanned barcode for a user from the database.
    //
    // Query parameter: ?format=<format>
    // <format>: the format of the response. The default is 
    // "barcode-only", which returns only the barcode as plain text. The second
    // option is "json", which returns the full response as a JSON object with 
    // the barcode, user, id, and date.
    // 
    // If no scanned barcodes are found for the user, a 204 no content response 
    // is returned.
    app.get("scans", ":user", "latest") { req async throws -> Response in

        guard let user = req.parameters.get("user") else {
            req.logger.error(
                "could not get user parameter for: \(req.url)"
            )
            throw Abort(.badRequest)
        }

        let format = try req.query.get(
            LatestScanOption.self,
            at: "format"
        )
        // let format = LatestScanOption.json

        req.logger.info(
            """
            retrieving latest scanned barcode for user \(user) with format: \
            \(format)
            """
        )

        let latestScan: ScannedBarcode? = try await barcodesCollection
            .find("user" == user)
            .sort(["date": -1])
            .limit(1)
            .decode(ScannedBarcode.self)
            .drain()
            .first

        guard let scan = latestScan else {
            req.logger.info(
                """
                no scanned barcodes found for user: \(user); \
                will return empty response
                
                """
            )
            return Response(status: .ok)
        }

        let scannedBarcodeResponse = ScannedBarcodeResponse(scan)
        
        req.logger.info(
            """
            retrieved latest scanned barcode for user \(user): \
            \(scan)
            """
        )

        let response = Response()
        switch format {
            case .barcodeOnly:
                let responseString = scannedBarcodeResponse.barcode
                try response.content.encode(responseString)
            case .json:
                try response.content.encode(
                    scannedBarcodeResponse,
                    using: JSONEncoder.sortedKeysPrettyPrinted
                )
        }

        return response

    }
    
    // MARK: GET /users
    //
    // Retrieves all users who have scanned barcodes.
    app.get("users") { req async throws -> [String] in

        req.logger.info("retrieving users")

        let users: [String] = try await barcodesCollection
            .distinctValues(forKey: "user")
            .compactMap { $0 as? String }
        
        req.logger.info("retrieved users: \(users)")

        return users

    }

    // MARK: - DELETE -

    // MARK: Delete /all-scans
    app.delete("all-scans") { req async throws -> String in

        req.logger.info("====== deleting all barcodes ======")

        let result = try await barcodesCollection.deleteAll(where: [:])

        req.logger.info("delete result: \(result)")

        return "====== deleted all barcodes ======"

    }

    // MARK: DELETE /all-scans/except-last?n=<n>
    //
    app.delete("all-scans", "except-last") { req async throws -> String in

        let n: Int = req.query["n"] ?? 5

        req.logger.info(
            "deleting all barcodes except the last \(n) scans"
        )

        let lastScans: [ScannedBarcode] = try await barcodesCollection
            .find()
            .sort(["date": -1])
            .limit(n)
            .decode(ScannedBarcode.self)
            .drain()

        let lastScanIDs = lastScans.map { $0._id }

        req.logger.info(
            "last \(n) scans: \(lastScans)"
        )

        let result = try await barcodesCollection.deleteAll(
            where: "_id" != ["$in": lastScanIDs]
        )

        req.logger.info(
            "delete result: \(result) (except last \(n) scans)"
        )

        return "deleted all barcodes except the last \(n) scans"

    }

    // MARK: DELETE /scans/:user
    //
    // Deletes all scanned barcodes for a user from the database.
    app.delete("scans", ":user") { req async throws -> String in

        let user = req.parameters.get("user")

        req.logger.info(
            "deleting all barcodes for user: \(user ?? "nil")"
        )

        let result = try await barcodesCollection.deleteAll(
            where: "user" == user
        )

        req.logger.info(
            "delete result for user \(user ?? "nil"): \(result)"
        )

        return "deleted all barcodes for user: \(user ?? "nil")"
    
    }

    // MARK: DELETE /scans/:user/except-last?n=<n>
    //
    app.delete("scans", ":user", "except-last") { req async throws -> String in

        let user = req.parameters.get("user")

        let n: Int = req.query["n"] ?? 5

        req.logger.info(
            "deleting all barcodes except the last \(n) scans for user: \(user ?? "nil")"
        )

        let lastScans: [ScannedBarcode] = try await barcodesCollection
            .find("user" == user)
            .sort(["date": -1])
            .limit(n)
            .decode(ScannedBarcode.self)
            .drain()

        let lastScanIDs = lastScans.map { $0._id }

        req.logger.info(
            "last \(n) scans for user \(user ?? "nil"): \(lastScans)"
        )

        let result = try await barcodesCollection.deleteAll(
            where: "user" == user && "_id" != ["$in": lastScanIDs]
        )

        req.logger.info(
            """
            delete result for user \(user ?? "nil"), \
            except last \(n) scans: \(result)
            """
        )

        return """
            deleted all barcodes except the last \(n) scans for user: \
            \(user ?? "nil")
            """

    }

    // MARK: DELETE /scans
    //
    // Deletes scanned barcodes by id and/or user from the database.
    //
    // Request body: ["<id1>", "<id2>", ...] or
    // { "ids": ["<id1>", "<id2>", ...], users: ["<user1>", "<user2>", ...]}
    // where at least one of `ids` or `users` must be present.
    // 
    // Or, as URL query parameters: a comma separated list:
    // /scans?ids=<id1>,<id2>...&users=<user1>,<user2>...
    //
    app.delete("scans") { req async throws -> String in

        let deleteScansRequest: DeleteScansRequestBody = try Result { 
            try req.content.decode(DeleteScansRequestBody.self)
        }
        .flatMapErrorThrowing({ error -> DeleteScansRequestBody in
            req.logger.info(
                """
                could not decode request body as JSON: \(error)
                """
            )
            return try req.query.decode(DeleteScansRequestBody.self)
        })
        .mapError({ error -> Error in
            req.logger.error(
                "could not decode request query parameters: \(error)"
            )
            return error
        })
        .get()

        req.logger.info(
            "deleting barcodes for: \(deleteScansRequest)"
        )

        let objectIDs = deleteScansRequest.ids
            // .compactMap({ ObjectId($0) })
            .compactMap({ ObjectId($0) })

        req.logger.info(
            "objectIDs: \(objectIDs)"
        )

        let idDoc: Document = ["_id": ["$in": objectIDs]]
        let userDoc: Document = ["user": ["$in": deleteScansRequest.users]]

        let doc: Document = [
            "$or": [
                idDoc,
                userDoc
            ]
        ]

        let result = try await barcodesCollection.deleteAll(
            where: doc
        )

        req.logger.info(
            "delete result: \(result) (request: \(deleteScansRequest)"
        )

        return "deleted barcodes:: \(deleteScansRequest)"

        // fatalError("not implemented")

    }

    // MARK: DELETE /all-scans/older?t=<seconds>
    // Deletes all scans for all users older than a specified number of seconds
    // from the database. The default is 300 seconds (5 minutes).
    app.delete("all-scans", "older") { req async throws -> String in

        req.logger.info(
            "\(req.route?.description ?? "couldn't get route description")"
        )

        let seconds = try req.query["t"].flatMap { secondsString throws -> Int in
            guard let int = Int(secondsString) else {
                req.logger.error(
                    """
                    could not convert secondsString '\(secondsString)' to Int
                    """
                )
                throw Abort(.badRequest)
            }
            return int
        } ?? 300  // DEFAULT: 300 seconds (5 minutes)

        req.logger.info(
            """
            deleting barcodes scanned more than \(seconds) seconds ago for all \
            users
            """
        )

        let date = Date().addingTimeInterval(TimeInterval(-seconds))

        let result = try await barcodesCollection.deleteAll(
            where: "date" < date
        )

        req.logger.info(
            """
            delete result for all barcodes scanned more than \(seconds) \
            seconds ago for all users: \
            \(result)
            """
        )

        return """
            deleted barcodes scanned more than \(seconds) seconds ago for all \
            users
            """

    }


    // MARK: DELETE /scans/<user>/older?t=<seconds>
    //
    // Deletes scanned barcodes for a user older than a specified number of
    // seconds (Int) from the database. The default is 300 seconds (5 minutes).
    app.delete("scans", ":user", "older") { req async throws -> String in

        req.logger.info(
            "\(req.route?.description ?? "couldn't get route description")"
        )

        guard let user = req.parameters.get("user") else {
            req.logger.error(
                "could not get user parameter for: \(req.url)"
            )
            throw Abort(.badRequest)
        }

        let seconds = try req.query["t"].flatMap { secondsString throws -> Int in
            guard let int = Int(secondsString) else {
                req.logger.error(
                    """
                    could not convert secondsString '\(secondsString)' to Int \
                    for user: \(user)
                    """
                )
                throw Abort(.badRequest)
            }
            return int
        } ?? 300  // DEFAULT: 300 seconds (5 minutes)

        req.logger.info(
            "deleting barcodes older than \(seconds) seconds for user: \(user)"
        )

        let date = Date().addingTimeInterval(TimeInterval(-seconds))

        let result = try await barcodesCollection.deleteAll(
            where: "user" == user && "date" < date
        )

        req.logger.info(
            """
            delete result for user \(user), older than \(seconds) seconds: \
            \(result)
            """
        )

        return """
            deleted barcodes older than \(seconds) seconds for user: \(user)
            """

    }

    // MARK: - Streaming -
    
    // TODO: GET /scans/:user/tail    
    // tails scans from user: server sends continuous stream of scanned barcodes
    // to the client

    // MARK: - Web Sockets -

    // MARK: WebSocket /ws-test
    //
    // A test websocket route that sends a message to the client when the
    // connection is established.
    // app.webSocket("ws-test") { req, ws in 
            
    //     req.logger.info("websocket connected")

    //     webSocketClients.add(WebSocketClient(id: UUID(), user: "peter", socket: ws))

    //     // do {
    //     // // try await Task.sleep(for: .seconds(10))
    //     //
    //     // req.logger.info("sending message to websocket")
    //     // try await ws.send("this is some text sent from the web socket")
    //     // req.logger.info("sent message to websocket")
    //     // 
    //     // // req.logger.info("sending *ANOTHER* message to websocket")
    //     // // try await ws.send("this is some text sent from the web socket")
    //     // // req.logger.info("sent *ANOTHER* message to websocket")
    //     // 
    //     // } catch let wsError {
    //     //     req.logger.error(
    //     //         "web socket error: \(wsError)"
    //     //     )
    //     // }

    // }

    // WebSocket /watch/:user
    //
    // 
    app.webSocket("watch", ":user") { req, ws in


        req.logger.info("Websocket /watch/:user: ws: \(ws)")

        guard let user = req.parameters.get("user") else {
            req.logger.error("could not get user parameter: \(req.url)")
            Task.detached(operation: { 
                do {
                    try await ws.close()
                } catch {
                    req.logger.error(
                        "could not close websocket: \(error)"
                    )
                }
            })
            return
        }

        req.logger.info(
            "websocket connected for user: \(user)"
        )

        let client = WebSocketClient(
            id: UUID(),
            user: user,
            socket: ws
        )

        webSocketClients.add(client)

    }

}

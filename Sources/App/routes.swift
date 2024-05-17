import Foundation
import Vapor
@preconcurrency import MongoKitten

func routes(_ app: Application) async throws {

    // MARK: Initialize Database

    let barcodesCollection = app.mongo["barcodes"]

    // MARK: GET /
    //
    // Returns a success message with the version string.
    app.get { req async -> String in
        let message = "success (version 0.1.9)"
        req.logger.info("\(message)")
        return message
    }

    // MARK: POST /scan/<user>
    //
    // Saves scanned barcode to the database.
    //
    // Request: 
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
                return try req.content.decode(ScanRequestBody.self, as: .json)
            })
            .flatMapErrorThrowing({ error -> ScanRequestBody in
                req.logger.debug("could not decode as JSON: \(error)")
                return try req.query.decode(ScanRequestBody.self)   
            })
            .flatMapErrorThrowing({ error -> ScanRequestBody in
                req.logger.debug(
                    "could not decode query for \(req.url): \(error)"
                )
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

    // MARK: GET /scans/:user
    //
    // Retrieves scanned barcodes for a user from the database.
    app.get("scans", ":user") { req async throws -> [ScannedBarcodeResponse] in

        let user = req.parameters.get("user")

        req.logger.info(
            "retrieving scanned barcodes for user: \(user ?? "nil")"
        )

        let scans: [ScannedBarcode] = try await barcodesCollection
            .find("user" == user)  // find all documents for the user
            .decode(ScannedBarcode.self)  // decode into model type
            .drain()  // load all documents into memory
        
        let response = ScannedBarcodeResponse.array(scans)
        req.logger.info(
            """
            retrieved \(response.count) scanned barcodes for user \
            \(user ?? "nil"):
            \(response)
            """
        )

        return response

    }
    
    // MARK: GET /scans
    //
    // Retrieves all scanned barcodes from the database.
    app.get("scans") { req async throws -> [ScannedBarcodeResponse] in

        // req.response.headers.add(name: "Content-Type", value: "application/json")

        req.logger.info("retrieving scanned barcodes")

        let scans: [ScannedBarcode] = try await barcodesCollection
            .find()  // find all documents in the collection
            .decode(ScannedBarcode.self)  // decode into model type
            .drain()  // load all documents into memory
        
        let response = ScannedBarcodeResponse.array(scans)
        req.logger.info(
            "retrieved \(response.count) scanned barcodes: \(response)"
        )

        return response

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
            "delete result: \(result) (user: \(user ?? "nil"))"
        )

        return "deleted all barcodes for user: \(user ?? "nil")"
    
    }

    // MARK: DELETE /scans
    //
    // Deletes scanned barcodes by id from the database.
    //
    // Request body: ["<id1>", "<id2>", ...]
    // 
    // Or, as a URL query parameter: a comma separated list:
    // /scans?ids=<id1>,<id2>...
    app.delete("scans") { req async throws -> String in

        let ids: [String] = try Result { 
            try req.content.decode([String].self, as: .json)
        }
        .flatMapErrorThrowing({ error -> [String] in
            req.logger.info(
                """
                could not decode request body as JSON: \(error)
                """
            )
            return try req.query.get([String].self, at: "ids")
        })
        .mapError({ error -> Error in
            req.logger.info(
                "could not decode request query parameter 'ids': \(error)"
            )
            return error
        })
        .get()

        req.logger.info(
            "deleting barcodes with ids: \(ids)"
        )

        if ids.isEmpty {
            throw Abort(.badRequest)
        }
        
        let doc: Document = [
            "_id": [
                "$in": ids.compactMap { ObjectId($0) }
            ]
        ]

        let result = try await barcodesCollection.deleteAll(
            where: doc
        )

        req.logger.info(
            "delete result: \(result) (ids: \(ids))"
        )

        return "deleted barcodes with ids: \(ids)"

    }

    app.get("users") { req async throws -> [String] in

        req.logger.info("retrieving users")

        let users: [String] = try await barcodesCollection
            .distinctValues(forKey: "user")
            .compactMap { $0 as? String }
        
        req.logger.info("retrieved users: \(users)")

        return users

    }

    // MARK: Web Sockets

    // WebSocket /watch/:user
    //
    // 
    app.webSocket("watch", ":user") { req, ws in

        guard let user = req.parameters.get("user") else {
            do {
                try await ws.send("invalid user")
            } catch {
                req.logger.error(
                    "could not send invalid user message: \(error)"
                )
            }
            do {
                try await ws.close()
            } catch {
                req.logger.error(
                    "could not close websocket: \(error)"
                )
            }
            return
        }

        req.logger.info("websocket connected for user: \(user)")

         // handle incoming messages

        ws.onText { ws, text in
            req.logger.info("received text for user '\(user)': \(text)")
        }

        // handle websocket disconnect
        ws.onClose.whenComplete { _ in
            req.logger.info("websocket disconnected for user: \(user)")
        }

        let changeStream: ChangeStream<ScannedBarcode>

        do {

            changeStream = try await barcodesCollection.buildChangeStream(
                options: { 
                    var options = ChangeStreamOptions()
                    options.fullDocument = .required
                    return options
                }(),
                ofType: ScannedBarcode.self,
                build: {
                    Match(where: "fullDocument.user" == user)
                }
            )
            req.logger.info("created watch stream for user: \(user)")

        } catch {
            req.logger.error(
                """
                could not create watch stream for user \(user): \(error)
                """
            )
            return
        }

        // handle change stream notifications
        do {

            for try await notification in changeStream {
                
                req.logger.info(
                    """
                    received change stream notification for user \(user): 
                    \(notification)
                    """
                )
                
                do {
                    // MARK: Send Refresh Message
                    try await ws.send("refresh")
                    req.logger.info("sent refresh message to user: \(user)")
                    // client should make a request to GET /scans to get the  
                    // updated list
                } catch {
                    req.logger.error(
                        """
                        could not send refresh message to user \(user): \
                        \(error)
                        """
                    )
                }

            }
        } catch {
            req.logger.error(
                """
                error handling change stream notification for user \
                \(user): \(error)
                """
            )
        }


    }


}

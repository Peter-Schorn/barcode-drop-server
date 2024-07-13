import Foundation
import Logging
import Vapor
@preconcurrency import MongoKitten

// import AWSS3
// import ClientRuntime
// import AWSElasticBeanstalk

func routes(_ app: Application) async throws {

    // MARK: - Initialize AWS -
    // let ebConfig = try await ElasticBeanstalkClient.ElasticBeanstalkClientConfiguration()
    // let elasticBeanstalkClient = ElasticBeanstalkClient(config: ebConfig)
    
    // guard let backendEnvironmentID = ProcessInfo.processInfo
    //         .environment["BARCODE_DROP_BACKEND_ENVIRONMENT_ID"] else {
    //     fatalError(
    //         """
    //         could not retrieve backend environment ID from \
    //         BARCODE_DROP_BACKEND_ENVIRONMENT_ID environment variable
    //         """
    //     )
    // }

    // MARK: - Protected Routes -
    // let protectedRoutes = ProtectedRoutes(
    //     elasticBeanstalkClient: elasticBeanstalkClient,
    //     backendEnvironmentID: backendEnvironmentID
    // )
    // try app.register(collection: protectedRoutes)

    // let scanStreamCollection = ScanStreamCollection(
    //     collection: app.barcodesCollection
    // )
    // try app.register(collection: scanStreamCollection)

    // MARK: - Send Scans to Users Task -

    /// Configures a task that sends all scans to all clients every 5 minutes.
    func configureSendScansToUserTask() {
        app.logger.info("configuring sendScansToUserTask")
        app.sendScansToUsersTask?.cancel()
        app.sendScansToUsersTask = Task.detached {
            while true {
                try await Task.sleep(for: .seconds(300))  // 5 minutes
                
                let date = Date()
                app.logger.info(
                    """
                    [\(date.iso8601String)] calling sendAllScansToAllUsers \
                    from sendScansToUsersTask
                    """
                )
                await sendAllScansToAllUsers()
            }
        }
    }

    // MARK: - Change Streams -

    @Sendable /* but is it though? */ 
    func configureChangeStream() async {

        app.logger.notice("configuring change stream")

        app.changeStreamTask?.cancel()

        let changeStream: ChangeStream<ScannedBarcode>

        do {

            changeStream = try await makeAppChangeStream(
                app.barcodesCollection
            )

            app.logger.info(
                "created app-level change stream"
            )

        } catch {
            app.logger.critical(
                """
                could not create app-level change stream: \(error)
                """
            )

            do {
                try await Task.sleep(for: .seconds(2))
                return await configureChangeStream()
            } catch {
                app.logger.error(
                    """
                    could not sleep before re-creating app-level change \
                    stream: \(error)
                    """
                )
                return
            }

        }

        app.changeStreamTask = Task.detached(operation: {
            do {
                try Task.checkCancellation()

                app.logger.notice("--- listening to change stream ---")
                
                
                // MARK: Handle Change Stream Notifications
                for try await notification in changeStream {
                    app.logger.info(
                        """
                        app-level change stream received notification: 
                        \(notification)
                        """
                    )

                    if 
                        let document = notification.fullDocument 
                                ?? notification.fullDocumentBeforeChange,
                        let user = document.user
                    {
                        
                        let userClients = app.webSocketClients.active
                            .filter { $0.user == user }


                        // group.addTask {
                        let sendNotificationToUserTask = Task.detached(operation: {
                            do {
                                try await sendNotificationToUser(
                                    notification: notification,
                                    clients: userClients,
                                    document: document,
                                    user: user
                                )

                            } catch {
                                app.logger.error(
                                    """
                                    error sending notification to user \(user): \
                                    clients: \(userClients):
                                    \(error)
                                    """
                                )
                            }
                        })

                        app.sendNotificationToUserTasks.append(
                            sendNotificationToUserTask
                        )

                    
                    }

                    // after handling each notification, check cancellation
                    try Task.checkCancellation()

                }

            } catch {
                if Task.isCancelled || error is CancellationError {
                    app.logger.info(
                        """
                        app-level change stream listener cancelled: \
                        \(error)
                        """
                    )
                    return
                }
                app.logger.error(
                    """
                    error handling app-level change stream notification: \
                    \(error)
                    """
                )
                app.logger.info(
                    "re-creating app-level change stream listener"
                )
                try await Task.sleep(for: .seconds(2))
                await configureChangeStream()
                await sendAllScansToAllUsers()
            }
        })
    
    }

    /**
     Sends a change stream notification to all clients with the same user.
     
     - Parameters:
         - notification: The change stream notification.
         - client: The client to send the notification to.
         - document: The document that was changed.
         - user: The user who scanned the barcode.
     */
    @Sendable
    func sendNotificationToUser(
        notification: ChangeStreamNotification<ScannedBarcode>,
        clients: [WebSocketClient],
        document: ScannedBarcode,
        user: String
    ) async throws {

        let clientIDs = clients.map(\.id)

        app.logger.info(
            """
            sendNotificationToUser: RECEIVED notification \
            for user \(user) (clientIDs: \(clientIDs)): \(notification)
            """
        )

        if [.insert, .replace, .update].contains(
            notification.operationType
        ) {

            let upsertScans = UpsertScans(
                document,
                transactionHash: notification.lsidTxtHash
            )

            app.logger.info(
                """
                sendNotificationToUser: sending upsertScans message to user \
                \(user) (clientIDs: \(clientIDs)): \(upsertScans) 
                """
            )
            
            await app.webSocketClients.sendJSON(
                upsertScans, 
                to: clients,
                user: user
            )

        }
        else if notification.operationType == .delete {

            let deleteScans = DeleteScans(
                document._id.hexString,
                transactionHash: notification.lsidTxtHash
            )

            let hash = notification.lsidTxtHash
                .map(\.description) ?? "nil"

            app.logger.info(
                """
                sending deleteScans message to user \
                \(user) (clientIDs: \(clientIDs)); hash: \(hash)): \
                \(deleteScans)
                """
            )

            await app.webSocketClients.sendJSON(
                deleteScans, 
                to: clients,
                user: user
            )

        }
        else {
            app.logger.info(
                """
                RECEIVED ANOTHER OPERATION TYPE for user \(user): \
                \(notification.operationType)
                """
            )
        }

    }


    /// Retrieves all scanned barcodes for a user from the database.
    /// - Parameter user: The user who scanned the barcodes. If `nil`, then all
    /// scanned barcodes are retrieved.
    @Sendable
    func retrieveAllScansForUser(_ user: String?) async throws -> [ScannedBarcodeResponse] {
        let scans: [ScannedBarcode] = try await app.barcodesCollection
            .find("user" == user)  // find all documents for the user
            .sort(["date": -1])  // sort by date in descending order
            .decode(ScannedBarcode.self)  // decode into model type
            .drain()  // load all documents into memory
            
        return ScannedBarcodeResponse.array(scans)
    }

    /// Sends all scanned barcodes for a user to the user's client(s).
    /// - Parameter user: The user who scanned the barcodes. If `nil`, then all
    /// scanned barcodes are sent to all clients.
    @Sendable
    func sendAllScansToUser(_ user: String?) async {
        
        guard let user = user else {
            return await sendAllScansToAllUsers()
        }
        
        do {
            app.logger.info("sending all scans to user \(user)")

            let scans = try await retrieveAllScansForUser(user)
            let replaceAllScans = ReplaceAllScans(scans)
            for client in app.webSocketClients.active {
                if client.user == user {
                    app.logger.info(
                        """
                        sendAllScansToUser: sending replaceAllScans message to \
                        user \(user) (client.id: \(client.id)) \
                        (\(scans.count) scans): \(replaceAllScans)
                        """
                    )
                    do {
                        try await client.sendJSON(replaceAllScans)

                    } catch {
                        app.logger.error(
                            """
                            sendAllScansToUser: could not send replaceAllScans \
                            message to user \(user) (client.id: \(client.id)): \
                            \(error)
                            """
                        )
                    }
                }
            }
        } catch {
            app.logger.error(
                "could not send all scans to user \(user): \(error)"
            )
        }

    }

    @Sendable
    func retrieveAllScansForAllUsers() async throws -> [ScannedBarcodeResponse] {
        let scans: [ScannedBarcode] = try await app.barcodesCollection
            .find()  // find all documents in the collection
            .sort(["date": -1])  // sort by date in descending order
            .decode(ScannedBarcode.self)  // decode into model type
            .drain()  // load all documents into memory
            
        return ScannedBarcodeResponse.array(scans)
    }

    @Sendable
    func sendAllScansToAllUsers() async {

        do {

            app.logger.info("sending all scans to all clients")

            let allScans = try await retrieveAllScansForAllUsers()

            app.logger.info(
                "retrieved all scans (\(allScans.count)): \(allScans)"
            )

            let userScans = Dictionary(grouping: allScans, by: { $0.user })

            for (user, scans) in userScans where user != nil {
                for client in app.webSocketClients.active where client.user == user {

                    let replaceAllScans = ReplaceAllScans(scans)

                    app.logger.info(
                        """
                        sendAllScansToAllUsers: sending replaceAllScans \
                        message to user \(user ?? "nil") \
                        (client.id: \(client.id)) (\(scans.count) scans): \
                        \(replaceAllScans)
                        """
                    )
                    
                    do {
                        try await client.sendJSON(replaceAllScans)

                    } catch {
                        app.logger.error(
                            """
                            sendAllScansToAllUsers: could not send \
                            replaceAllScans message to user \(user ?? "nil") \
                            (client.id: \(client.id)): \(error)
                            """
                        )
                    }

                }
            }

            app.logger.info("sent all scans to all clients")

        } catch {
            app.logger.error(
                "could not send all scans to all clients: \(error)"
            )
        }

    }

    @Sendable
    func deleteBarcodesWithTransaction(
        _ filterDoc: Document
    ) async throws -> DeleteReply {

        app.logger.info(
            """
            deleteBarcodesWithTransaction: deleting with transaction: \
            filterDoc: \(filterDoc)
            """
        )

        return try await app.mongo.withTransaction(
            autoCommitChanges: false,
            { db in
                let barcodesCollection = db["barcodes"]
                let result = try await barcodesCollection.deleteAll(
                    where: filterDoc
                )
                app.logger.info(
                    """
                    deleteBarcodesWithTransaction: delete result: \(result)
                    """
                )
                return result
            }
        )

    }

    @Sendable
    func deleteBarcodesWithTransaction<Q: MongoKittenQuery & Sendable>(
        _ filterDoc: Q
    ) async throws -> DeleteReply {
        return try await deleteBarcodesWithTransaction(filterDoc.makeDocument())
    }

    @Sendable
    func getAllSplashText() async throws -> [SplashText] {
        let splashTexts: [SplashText] = try await app.splashTextCollection
            .find()
            .decode(SplashText.self)
            .drain()
            // .map { $0.message }
        return splashTexts
    }

    @Sendable
    func getRandomSplashText() async throws -> SplashText? {
        
        let randomSplashText: SplashText? = try await app.splashTextCollection
            .buildAggregate(build: {
                Sample(1)
            })
            .decode(SplashText.self)
            .firstResult()

        return randomSplashText

    }

    // MARK: - Configure Tasks -

    configureSendScansToUserTask()
    await configureChangeStream()

    // MARK: - Routes -

    app.logger.info("setting up routes")

    // MARK: GET /
    //
    // Returns a success message with the version string.
    app.get { req async -> String in
        let message = "success (version 0.5.2)"
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
    app.post("scan", ":user") { req async throws -> Response in
        do {

            /// the date the barcode was received by the server
            let date = Date()

            let user = req.parameters.get("user")

            let scan: ScannedBarcodeRequest = try Result<ScannedBarcodeRequest, Error>{
                // first try to decode using the content type in the header or 
                // default content type
                try req.content.decode(ScannedBarcodeRequest.self)
            }
            // now, try other content types
            .flatMapErrorThrowing({ error -> ScannedBarcodeRequest in
                req.logger.debug(
                    """
                    could not decode as header-specified or default content type: \
                    (\(req.content.contentType?.description ?? "nil")):
                    \(error)
                    """
                )
                return try req.query.decode(ScannedBarcodeRequest.self)   
            })
            .flatMapErrorThrowing({ error -> ScannedBarcodeRequest in
                req.logger.debug(
                    "could not decode query for \(req.url): \(error)"
                )
                return try req.content.decode(ScannedBarcodeRequest.self, as: .json)
            })
            .flatMapErrorThrowing({ error -> ScannedBarcodeRequest in
                req.logger.debug("could not decode as JSON: \(error)")
                return try req.content.decode(ScannedBarcodeRequest.self, as: .formData)
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
                id: scan.id,
                barcode: scan.barcode,
                user: user,
                date: date // save date barcode was scanned to the database
            )

            // insert the scanned barcode into the database
            try await app.barcodesCollection.insertEncoded(scannedBarcode)

            let responseText = """
                user '\(user ?? "nil")' scanned '\(scannedBarcode.barcode)' \
                (id: \(scannedBarcode._id.hexString))
                """
            
            let response = Response()
            response.headers.add(
                name: "barcode-id", 
                value: scannedBarcode._id.hexString
            )
            try response.content.encode(responseText)
            return response

        } catch let postBarcodeError {

            req.logger.warning(
                """
                error in POST /scan/<user>: \(postBarcodeError)
                    user: \(req.parameters.get("user") ?? "nil")
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

        let queryOptions = try req.query.decode(
            GetScansQuery.self
        )

        req.logger.info(
            "retrieving scanned barcodes with queryOptions: \(queryOptions)"
        )

        
        let scannedBarcodesResponse = try await retrieveAllScansForAllUsers()
        
        req.logger.info(
            """
            retrieved \(scannedBarcodesResponse.count) scanned barcodes:
            \(scannedBarcodesResponse)
            """
        )

        let response = Response()
        switch queryOptions.format {
            case .barcodesOnly:
                let responseString = scannedBarcodesResponse
                    .map { $0.barcode }
                    .joined(separator: "\n")
                try response.content.encode(responseString)
            case .json:
                try response.content.encode(
                    scannedBarcodesResponse,
                    using: queryOptions.encoder
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

        let queryOptions = try req.query.decode(
            GetScansQuery.self
        )

        // let format = ScansOption.json

        req.logger.info(
            """
            retrieving scanned barcodes for user \(user ?? "nil") \
            with queryOptions: \(queryOptions)
            """
        )

        let scannedBarcodesResponse = try await retrieveAllScansForUser(user)
        
        req.logger.info(
            """
            retrieved \(scannedBarcodesResponse.count) \
            scanned barcodes for user \(user ?? "nil"):
            \(scannedBarcodesResponse)
            """
        )

        // return scannedBarcodesResponse
        
        let response = Response()
        switch queryOptions.format {
            case .barcodesOnly:
                let responseString = scannedBarcodesResponse
                    .map { $0.barcode }
                    .joined(separator: "\n")
                try response.content.encode(responseString)
            case .json:
                try response.content.encode(
                    scannedBarcodesResponse,
                    using: queryOptions.encoder
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

        let latestScan: ScannedBarcode? = try await app.barcodesCollection
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
                will return 204 No Content response
                """
            )
            return Response(status: .noContent)
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

        response.headers.add(
            name: "barcode-id", 
            value: "\(scannedBarcodeResponse.id)"
        )

        return response

    }
    
    // MARK: GET /users
    //
    // Retrieves all users who have scanned barcodes.
    app.get("users") { req async throws -> [String] in

        req.logger.info("retrieving users")

        let users: [String] = try await app.barcodesCollection
            .distinctValues(forKey: "user")
            .compactMap { $0 as? String }
        
        req.logger.info("retrieved users: \(users)")

        return users

    }

    // MARK: Splash Text

    // MARK: GET /splash-text
    //
    // Retrieves all splash text from the database.
    app.get("splash-text") { req async throws -> [String] in

        req.logger.info("retrieving splash text")

        let splashTexts = try await getAllSplashText()

        req.logger.info("retrieved splash text: \(splashTexts)")

        return splashTexts.map(\.message)

    }

    // MARK: GET /splash-text/random
    //
    // Retrieves a random splash text from the database.
    app.get("splash-text", "random") { req async throws -> String in

        req.logger.info("retrieving random splash text")

        guard let randomSplashText: SplashText = try await getRandomSplashText() else {
            req.logger.error("could not get random splash text")
            throw Abort(.internalServerError)
        }

        req.logger.info("retrieved random splash text: \(randomSplashText)")

        return randomSplashText.message

    }

    // MARK: - POST -

    // MARK: POST /splash-text
    //
    // Adds a splash text to the database.
    //
    // Request body: { "message": "Hello, World!" }
    app.post("splash-text") { req async throws -> String in

        let splashTextRequestBody = try req.content.decode(
            SplashTextRequest.self
        )

        let splashText = SplashText(splashTextRequestBody)

        req.logger.info(
            """
            adding splash text: \(splashText); \
            splashTextRequestBody: \(splashTextRequestBody)
            """
        )

        try await app.splashTextCollection.insertEncoded(splashText)

        req.logger.info("added splash text: \(splashText)")

        let splashTextResponse = SplashTextResponse(splashText)
        return "added splash text: \(splashTextResponse)"

    }


    // MARK: - DELETE -

    // MARK: DELETE /splash-text
    //
    // deletes splash texts by IDs from the database
    app.delete("splash-text") { req async throws -> String in

        let ids: [String] = try req.content.decode([String].self)

        req.logger.info("deleting splash text with ids: \(ids)")

        // let idDoc: Document = ["_id": ["$in": objectIDs]]

        let objectIDs = ids.compactMap { ObjectId($0) }

        let result = try await app.splashTextCollection.deleteAll(
            // where: "_id" == ["$in": ids.compactMap { ObjectId($0) }]
            where: ["_id": ["$in": objectIDs]]
        )

        req.logger.info("delete result: \(result)")

        return "deleted splash text with ids: \(ids)"

    }


    // MARK: Delete /all-scans
    app.delete("all-scans") { req async throws -> String in

        req.logger.info("====== deleting all barcodes ======")

        // let result = try await app.barcodesCollection.deleteAll(where: [:])
        let result = try await deleteBarcodesWithTransaction([:])

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

        let lastScans: [ScannedBarcode] = try await app.barcodesCollection
            .find()
            .sort(["date": -1])
            .limit(n)
            .decode(ScannedBarcode.self)
            .drain()

        let lastScanIDs = lastScans.map { $0._id }

        req.logger.info(
            "last \(n) scans: \(lastScans)"
        )

        // let result = try await app.barcodesCollection.deleteAll(
        //     where: "_id" != ["$in": lastScanIDs]
        // )
        let result = try await deleteBarcodesWithTransaction(
            "_id" != ["$in": lastScanIDs]
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

        // let transaction = try await app.mongo.startTransaction(autoCommitChanges: false)
        // let barcodesCollection = transaction["barcodes"]

        // let result = try await app.barcodesCollection.deleteAll(
        //     where: "user" == user
        // )
        let result = try await deleteBarcodesWithTransaction("user" == user)

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

        let lastScans: [ScannedBarcode] = try await app.barcodesCollection
            .find("user" == user)
            .sort(["date": -1])
            .limit(n)
            .decode(ScannedBarcode.self)
            .drain()

        let lastScanIDs = lastScans.map { $0._id }

        req.logger.info(
            "last \(n) scans for user \(user ?? "nil"): \(lastScans)"
        )

        let result = try await deleteBarcodesWithTransaction(
            "user" == user && "_id" != ["$in": lastScanIDs]
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

        let deleteScansRequest: DeleteScansRequest = try Result { 
            try req.content.decode(DeleteScansRequest.self)
        }
        .flatMapErrorThrowing({ error -> DeleteScansRequest in
            req.logger.info(
                """
                could not decode request body as JSON: \(error)
                """
            )
            return try req.query.decode(DeleteScansRequest.self)
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

        // let result = try await app.barcodesCollection.deleteAll(
        //     where: doc
        // )
        let result = try await deleteBarcodesWithTransaction(doc)

        req.logger.info(
            "delete result: \(result) (request: \(deleteScansRequest)"
        )

        return "deleted barcodes: \(deleteScansRequest)"

        // fatalError("not implemented")

    }

    // MARK: DELETE /all-scans/older?t=<seconds>
    // Deletes all scans for all users older than a specified number of seconds
    // from the database. The default is 3,600 seconds (1 hour).
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
        } ?? 3_600  // DEFAULT: 3,600 seconds (1 hour)

        req.logger.info(
            """
            deleting barcodes scanned more than \(seconds) seconds ago for all \
            users
            """
        )

        let date = Date().addingTimeInterval(TimeInterval(-seconds))

        // let result = try await app.barcodesCollection.deleteAll(
        //     where: "date" < date
        // )
        let result = try await deleteBarcodesWithTransaction("date" < date)

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
    // seconds (Int) from the database. The default is 3,600 seconds (1 hour).
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

        let seconds = try req.query["t"]
            .flatMap { (secondsString: String) throws -> Int in
                guard let int = Int(secondsString) else {
                    req.logger.error(
                        """
                        could not convert secondsString \
                        '\(secondsString)' to Int for user: \(user)
                        """
                    )
                    throw Abort(.badRequest)
                }
                return int
            } ?? 3_600  // DEFAULT: 3,600 seconds (1 hour)

        req.logger.info(
            "deleting barcodes older than \(seconds) seconds for user: \(user)"
        )

        let date = Date().addingTimeInterval(TimeInterval(-seconds))

        // let result = try await app.barcodesCollection.deleteAll(
        //     where: "user" == user && "date" < date
        // )
        let result = try await deleteBarcodesWithTransaction(
            "user" == user && "date" < date
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

    // MARK: WebSocket /watch/:user
    //
    // 
    app.webSocket("watch", ":user") { req, ws in


        req.logger.info("Websocket /watch/:user: ws: \(ws)")

        guard let user = req.parameters.get("user") else {
            req.logger.error("could not get user parameter: \(req.url)")
            let closeSocketTask = Task.detached(operation: { 
                do {
                    try await ws.close()
                } catch {
                    req.logger.error(
                        "could not close websocket: \(error)"
                    )
                }
            })
            app.addOtherTask(closeSocketTask)
            return
        }

        let client = WebSocketClient(
            id: UUID(),
            user: user,
            socket: ws
        )

        app.webSocketClients.add(client)

        let sendScansTask = Task.detached {
            try await Task.sleep(for: .seconds(2))
            await sendAllScansToUser(user)
        }
        app.addOtherTask(sendScansTask)

        req.logger.info(
            """
            websocket connected for user: \(user) \
            (client.id: \(client.id))
            """
        )

    }

}

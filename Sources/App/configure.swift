import Foundation
import Vapor
@preconcurrency import MongoKitten
@preconcurrency import Meow

// configures your application
public func configure(_ app: Application) async throws {
    
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // MARK: - CORS Middleware -
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [
            .GET,
            .POST,
            .PUT,
            .OPTIONS,
            .DELETE,
            .PATCH
        ],
        allowedHeaders: [
            .accept,
            .authorization,
            .contentType,
            .origin,
            .xRequestedWith,
            .userAgent,
            .accessControlAllowOrigin
        ]
    )

    let cors = CORSMiddleware(configuration: corsConfiguration)

    // cors middleware should come before default error middleware 
    // using `at: .beginning`
    app.middleware.use(cors, at: .beginning)

    // ---

    // MARK: Initialize Database

    guard let password = ProcessInfo.processInfo
            .environment["BARCODE_DROP_DATABASE_PASSWORD"] else {
        fatalError(
            """
            could not retrieve password from BARCODE_DROP_DATABASE_PASSWORD \
            environment variable
            """
        )
    }

    let connectionURI = "mongodb+srv://peter:\(password)@barcode-drop.w0gnolp.mongodb.net/Barcodes"

    try app.initializeMongoDB(connectionString: connectionURI)

    try await routes(app)
    
}

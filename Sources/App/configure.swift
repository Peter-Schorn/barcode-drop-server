import Foundation
import Vapor
@preconcurrency import MongoKitten
@preconcurrency import Meow

// configures your application
public func configure(_ app: Application) async throws {
    
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

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

    let connectionURI = "mongodb+srv://peter:\(password)@barcode-drop.5wwntye.mongodb.net/Barcodes"

    try app.initializeMongoDB(connectionString: connectionURI)

    try await routes(app)
    
}

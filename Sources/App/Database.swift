import Foundation
import Vapor
@preconcurrency import MongoKitten
@preconcurrency import Meow

extension Request {
    public var mongo: MongoDatabase {
        return application.mongo.adoptingLogMetadata([
            "request-id": .string(id)
        ])
    }
}

private struct MongoDBStorageKey: StorageKey {
    typealias Value = MongoDatabase
}

extension Application {
    public var mongo: MongoDatabase {
        get {
            storage[MongoDBStorageKey.self]!
        }
        set {
            storage[MongoDBStorageKey.self] = newValue
        }
    }
    
    public func initializeMongoDB(connectionString: String) throws {
        self.mongo = try MongoDatabase.lazyConnect(to: connectionString)
    }
}

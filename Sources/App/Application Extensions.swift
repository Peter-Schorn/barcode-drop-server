import Foundation
import Vapor
@preconcurrency import MongoKitten
@preconcurrency import Meow


private struct MongoDBStorageKey: Sendable, StorageKey {
    typealias Value = MongoDatabase
}

private struct WebsocketClientsStorageKey: Sendable, StorageKey {
    typealias Value = WebsocketClients
}

private struct ChangeStreamTaskStorageKey: Sendable, StorageKey {
    typealias Value = Task<Void, Error>
}

extension Application {

    var changeStreamTask: Task<Void, Error>? {
        get {
            return self.storage[ChangeStreamTaskStorageKey.self]
        }
        set {
            self.storage[ChangeStreamTaskStorageKey.self] = newValue
        }
    }

    var webSocketClients: WebsocketClients {
        get {
            return self.storage[WebsocketClientsStorageKey.self]!
        }
        set {
            self.storage[WebsocketClientsStorageKey.self] = newValue
        }
    }

    var mongo: MongoDatabase {
        get {
            return self.storage[MongoDBStorageKey.self]!
        }
        set {
            self.storage[MongoDBStorageKey.self] = newValue
        }
    }

    var barcodesCollection: MongoCollection {
        get { 
            return self.mongo["barcodes"]
        }
    }
    
    func initializeMongoDB(connectionString: String) throws {
        self.mongo = try MongoDatabase.lazyConnect(to: connectionString)
    }

}

/*
 let webSocketClients = WebsocketClients(
     eventLoop: app.eventLoopGroup.next()
 )
 */

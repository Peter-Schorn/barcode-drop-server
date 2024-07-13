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

private struct SendNotificationToUserTaskStorageKey: Sendable, StorageKey {
    typealias Value = [Task<Void, Never>]
}

private struct SendScansToUsersTaskStorageKey: Sendable, StorageKey {
    typealias Value = Task<Void, Error>
}

private struct OtherTasksStorageKey: Sendable, StorageKey {
    typealias Value = [Task<Void, Never>]
}

private struct OtherThrowingTasksStorageKey: Sendable, StorageKey {
    typealias Value = [Task<Void, Error>]
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

    var sendNotificationToUserTasks: [Task<Void, Never>] {
        get {
            return self.storage[SendNotificationToUserTaskStorageKey.self] ?? []
        }
        set {
            self.storage[SendNotificationToUserTaskStorageKey.self] = newValue
        }
    }

    var sendScansToUsersTask: Task<Void, Error>? {
        get {
            return self.storage[SendScansToUsersTaskStorageKey.self]
        }
        set {
            self.storage[SendScansToUsersTaskStorageKey.self] = newValue
        }
    }

    var otherTasks: [Task<Void, Never>] {
        get {
            return self.storage[OtherTasksStorageKey.self] ?? []
        }
        set {
            self.storage[OtherTasksStorageKey.self] = newValue
        }
    }

    func addOtherTask(_ task: Task<Void, Never>) {
        self.otherTasks.append(task)
    }

    var otherThrowingTasks: [Task<Void, Error>] {
        get {
            return self.storage[OtherThrowingTasksStorageKey.self] ?? []
        }
        set {
            self.storage[OtherThrowingTasksStorageKey.self] = newValue
        }
    }

    func addOtherTask(_ task: Task<Void, Error>) {
        self.otherThrowingTasks.append(task)
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
    
    var splashTextCollection: MongoCollection {
        get {
            return self.mongo["splash_text"]
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

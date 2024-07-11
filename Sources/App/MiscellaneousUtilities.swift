#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import Foundation
import WebSocketKit
import Foundation
import Vapor
import MongoCore
@preconcurrency import MongoKitten

extension Result {

    func flatMapErrorThrowing(
        _ transform: (Failure) throws -> Success
    ) -> Result<Success, Error> {

        return self.flatMapError { error in
            return Result<Success, Error> {
                try transform(error)
            }
        }

    }

}

extension JSONEncoder {

    static let iso8601: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    
    static let sortedKeys: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let sortedKeysPrettyPrinted: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

}

extension WebSocket {

    func sendJSON<T: Encodable>(
        _ value: T,
        using encoder: JSONEncoder = .iso8601
    ) async throws {

        let data = try encoder.encode(value)
        try await send(raw: data, opcode: .text)

    }


}


func makeAppChangeStream(
    _ collection: MongoCollection
) async throws -> ChangeStream<ScannedBarcode> {

    return try await collection.buildChangeStream(
        options: { () -> MongoKitten.ChangeStreamOptions in
            var options = ChangeStreamOptions()
            options.fullDocument = .required
            options.fullDocumentBeforeChange = .required
            return options
        }(),
        ofType: ScannedBarcode.self,
        build: {
            // match all users
            // Match(where: "fullDocument.user" == user)
        }
    )

}

extension MongoDatabase {

    func withTransaction<T>(
        autoCommitChanges autoCommit: Bool,
        with options: MongoSessionOptions = .init(),
        transactionOptions: MongoTransactionOptions? = nil,
        _ body: @escaping (MongoTransactionDatabase) async throws -> T
    ) async throws -> T {

        let transaction = try await self.startTransaction(
            autoCommitChanges: autoCommit,
            with: options,
            transactionOptions: transactionOptions
        )

        let result = try await body(transaction)

        try await transaction.commit()

        return result
        
    }

}

extension ChangeStreamNotification {

    var lsidBinary: Binary? {
        guard let lsid = self.lsid else {
            return nil
        }
        return (lsid["id"] as? Binary)
    }

    // identify notifications from the same transaction
    var lsidTxtHash: Int? {
        
        guard let lsidData = self.lsidBinary?.data else {
            return nil
        }

        guard let txtNumber = self.txnNumber else {
            return nil
        }

        var hasher = Hasher()
        hasher.combine(lsidData)
        hasher.combine(txtNumber)

        return hasher.finalize()

    }

}

extension ISO8601DateFormatter {

    static let defaultFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime, 
        ]
        return formatter
    }()

}

extension Date {

    var iso8601String: String {
        return ISO8601DateFormatter.defaultFormatter.string(from: self)
    }

}

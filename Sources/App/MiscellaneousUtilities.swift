import Foundation
import WebSocketKit
import Foundation
import Vapor
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

    static let iso8601: JSONEncoder = {
        let encoder = JSONEncoder()
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

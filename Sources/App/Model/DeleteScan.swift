import Foundation
import Vapor
import MongoKitten

/**
 Represents the message sent from the server to the client via a WebSocket
 connection to delete a scan from the database.

 Example JSON:

 {    
     type: "deleteScan",
     id: "123e4567-e89b-12d3-a456-426614174000"
 }      
 */
struct DeleteScan: Sendable, Content {

    static let type = "deleteScan"

    static let defaultContentType = HTTPMediaType.json

    let id: String

    init(_ id: String) {
        self.id = id
    }

    init(from decoder: Decoder) throws {

        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let type = try container.decode(String.self, forKey: .type)
        
        guard type == Self.type else {

            let debugDescription = """
                Invalid type: \(type) (expected \(Self.type))
                """

            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: debugDescription
            )

        }

        self.id = try container.decode(
            String.self, 
            forKey: .id
        )

    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.type, forKey: .type)
        try container.encode(self.id, forKey: .id)
    }

    enum CodingKeys: String, CodingKey {
        case type
        case id
    }

}

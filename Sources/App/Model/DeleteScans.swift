import Foundation
import Vapor
import MongoKitten

/**
 Represents the message sent from the server to the client via a WebSocket
 connection to delete scans from the database.

 The transactionHash 

 Example JSON:

 {    
     type: "deleteScans",
     ids: ["66913db6e53ca35a6c7edd39", "66913db2db0ee00492392758"],
     transactionHash: 123456
 }      
 */
struct DeleteScans: Sendable, Content {

    static let type = "deleteScans"

    static let defaultContentType = HTTPMediaType.json

    let ids: [String]

    let transactionHash: Int?

    init(_ ids: [String], transactionHash: Int? = nil) {
        self.ids = ids
        self.transactionHash = transactionHash
    }

    init(_ id: String, transactionHash: Int? = nil) {
        self.init([id], transactionHash: transactionHash)
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

        self.ids = try container.decode(
            [String].self, 
            forKey: .ids
        )

        self.transactionHash = try container.decodeIfPresent(
            Int.self, 
            forKey: .transactionHash
        )

    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.type, forKey: .type)
        try container.encode(self.ids, forKey: .ids)
        try container.encodeIfPresent(
            self.transactionHash, forKey: .transactionHash
        )
    }

    enum CodingKeys: String, CodingKey {
        case type
        case ids
        case transactionHash
    }

}

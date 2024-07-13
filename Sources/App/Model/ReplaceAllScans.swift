import Foundation
import Vapor
import MongoKitten

/**
 Represents the message sent from the server to the client via a WebSocket
 connection to replace all scans in the database with a new set of scans.

 Example JSON:

 {    
     type: "replaceAllScans",
     scans: [
         {
             barcode: "second",
             user: "schornpe",
             id: "123e4567-e89b-12d3-a456-426614174000",
             date: "2021-08-01T12:00:00Z"
         },
         {
             barcode: "first",
             user: "schornpe",
             id: "123e4567-e89b-12d3-a456-426614174000",
             date: "2021-08-01T11:55:00Z"
         }
     ]   
 }      
 */
struct ReplaceAllScans: Sendable, Content {

    static let type = "replaceAllScans"

    static let defaultContentType = HTTPMediaType.json

    let scans: [ScannedBarcodeResponse]

    /// A unique identifier for all messages from the same transaction.
    let transactionHash: Int?

    init(_ scans: [ScannedBarcodeResponse], transactionHash: Int? = nil) {
        self.scans = scans
        self.transactionHash = transactionHash
    }

    init(_ scans: [ScannedBarcode], transactionHash: Int? = nil) {
        self.scans = ScannedBarcodeResponse.array(scans)
        self.transactionHash = transactionHash
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

        self.scans = try container.decode(
            [ScannedBarcodeResponse].self, 
            forKey: .scans
        )

        self.transactionHash = try container.decodeIfPresent(
            Int.self, 
            forKey: .transactionHash
        )

    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.type, forKey: .type)
        try container.encode(self.scans, forKey: .scans)
        try container.encodeIfPresent(
            self.transactionHash, forKey: .transactionHash
        )
    }

    enum CodingKeys: String, CodingKey {
        case transactionHash
        case type
        case scans
    }

}

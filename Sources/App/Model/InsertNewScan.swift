import Foundation
import Vapor
import MongoKitten

/**
 Represents the message sent from the server to the client via a WebSocket
 connection to insert a new scan into the database.

 Example JSON:

 {    
     type: "insertNewScan",
     newScan: {
         barcode: "1234567890",
         user: "schornpe",
         id: "123e4567-e89b-12d3-a456-426614174000",
         date: "2021-08-01T12:00:00Z"
     }   
 }      
 */
struct InsertNewScan: Sendable, Content {

    static let defaultContentType: HTTPMediaType = .json

    let newScan: ScannedBarcodeResponse

    init(_ newScan: ScannedBarcodeResponse) {
        self.newScan = newScan
    }

    init(_ newScan: ScannedBarcode) {
        self.init(ScannedBarcodeResponse(newScan))
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

        self.newScan = try container.decode(
            ScannedBarcodeResponse.self, 
            forKey: .newScan
        )

    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.type, forKey: .type)
        try container.encode(self.newScan, forKey: .newScan)
    }

    static let type = "insertNewScan"

    enum CodingKeys: String, CodingKey {
        case type
        case newScan
    }

}

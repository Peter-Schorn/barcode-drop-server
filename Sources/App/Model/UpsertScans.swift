import Foundation
import Vapor
import MongoKitten

/**
 Represents the message sent from the server to the client via a WebSocket
 connection to insert new scans/update existing scans.

 Example JSON:

 {    
     type: "upsertScans",
     newScans: {
         barcode: "1234567890",
         user: "schornpe",
         id: "123e4567-e89b-12d3-a456-426614174000",
         date: "2021-08-01T12:00:00Z"
     }   
 }      
 */
struct UpsertScans: Sendable, Content {

    static let type = "upsertScans"

    static let defaultContentType = HTTPMediaType.json

    let newScans: [ScannedBarcodeResponse]

    init(_ newScans: [ScannedBarcodeResponse]) {
        self.newScans = newScans
    }

    init(_ newScan: ScannedBarcodeResponse) {
        self.init([newScan])
    }

    init(_ newScan: ScannedBarcode) {
        self.init(ScannedBarcodeResponse(newScan))
    }

    init(_ newScans: [ScannedBarcode]) {
        let newScans = newScans.map { ScannedBarcodeResponse($0) }
        self.init(newScans)
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

        self.newScans = try container.decode(
            [ScannedBarcodeResponse].self, 
            forKey: .newScans
        )

    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.type, forKey: .type)
        try container.encode(self.newScans, forKey: .newScans)
    }

    enum CodingKeys: String, CodingKey {
        case type
        case newScans
    }

}

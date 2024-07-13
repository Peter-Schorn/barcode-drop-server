import Foundation
import Vapor
import MongoKitten

/// Represents a scanned barcode. Decoded from the body of the request to 
/// POST /scan as url-encoded form data.
struct ScannedBarcodeRequest: Sendable, Content {

    static let defaultContentType = HTTPMediaType.urlEncodedForm

    let barcode: String
    let id: ObjectId

    init(barcode: String, id: ObjectId? = nil) {
        self.barcode = barcode
        self.id = id ?? ObjectId()
    }

    init(from decoder: any Decoder) throws {
        
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decodeIfPresent(
            ObjectId.self, forKey: .id
        ) ?? ObjectId()

        decodeBarcode: do {
            for barcodeKey in CodingKeys.barcodeKeys {
                if container.contains(barcodeKey) {
                    if let barcode = try container.decodeIfPresent(
                        String.self, forKey: barcodeKey
                    ) {
                        self.barcode = barcode
                        break decodeBarcode
                    }
                }
            }
            // the container does not contain any of the barcode keys
            let barcodeKeysString = CodingKeys.barcodeKeys
                .map(\.rawValue)
                .joined(separator: ", ")

            let debugDescription = """
                expected one of the following keys in the request body: \
                \(barcodeKeysString)
                """
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: debugDescription
            ))
        }

    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .id)
        try container.encode(self.barcode, forKey: .barcode)
    }

    private enum CodingKeys: String, CodingKey {

        case id

        case barcode
        case text

        // all of the keys that can be used to encode the actual barcode string
        static let barcodeKeys: [Self] = [
            .barcode,
            .text
        ]
    }

}

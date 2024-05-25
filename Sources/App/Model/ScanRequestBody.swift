import Foundation
import Vapor
import MongoKitten

/// Represents a scanned barcode. Decoded from the body of the request to 
/// POST /scan as url-encoded form data.
struct ScanRequestBody: Sendable, Content {

    static let defaultContentType: HTTPMediaType = .urlEncodedForm

    let barcode: String

    init(barcode: String) {
        self.barcode = barcode
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.barcode) {
            self.barcode = try container.decode(String.self, forKey: .barcode)
        } 
        else if container.contains(.text) {
            self.barcode = try container.decode(String.self, forKey: .text)
        }
        else {
            let debugDescription = """
                missing both 'barcode' and 'text' keys in request body.
                """
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: debugDescription
            ))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.barcode, forKey: .barcode)
    }

    private enum CodingKeys: String, CodingKey {
        case barcode
        case text
    }

}

import Foundation
import Vapor
import MongoKitten

/// Represents a scanned barcode. Decoded from the body of the request to 
/// POST /scan as url-encoded form data.
struct ScanRequestBody: Sendable, Content {

    static let defaultContentType: HTTPMediaType = .urlEncodedForm

    let barcode: String

}

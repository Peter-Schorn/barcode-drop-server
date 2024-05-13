import Foundation
import Vapor
@preconcurrency import MongoKitten
@preconcurrency import Meow

/// Represents a scanned barcode. Decoded from the body of the request to 
/// POST /scan as url-encoded form data.
struct ScanRequestBody: Content {

    static let defaultContentType: HTTPMediaType = .urlEncodedForm

    let barcode: String

}

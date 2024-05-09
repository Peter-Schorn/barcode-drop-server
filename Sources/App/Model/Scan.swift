import Foundation
import Vapor

struct Scan: Content {

    static let defaultContentType: HTTPMediaType = .urlEncodedForm

    let barcode: String

}

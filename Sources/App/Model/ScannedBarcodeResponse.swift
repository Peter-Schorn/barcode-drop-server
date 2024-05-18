import Foundation
import Vapor
import MongoKitten

/// Represents a scanned barcode. Used in the response to GET /scans.
struct ScannedBarcodeResponse: Sendable, Content {

    static let defaultContentType: HTTPMediaType = .json

    let barcode: String
    let user: String?
    let id: String
    let date: Date

    init(
        barcode: String, 
        user: String?, 
        id: String,  // <---
        date: Date
    ) {
        self.barcode = barcode
        self.user = user
        self.id = id
        self.date = date
    }

    init(
        barcode: String, 
        user: String?, 
        id: ObjectId,  // <--- convert ObjectId to string
        date: Date
    ) {
        self.barcode = barcode
        self.user = user
        self.id = id.hexString  // <---
        self.date = date
    }

    init(_ scannedBarcode: ScannedBarcode) {
        self.barcode = scannedBarcode.barcode
        self.user = scannedBarcode.user
        self.id = scannedBarcode._id.hexString
        self.date = scannedBarcode.date
    }

    static func array(
        _ scannedBarcodes: [ScannedBarcode]
    ) -> [ScannedBarcodeResponse] {

        return scannedBarcodes
            .map({ ScannedBarcodeResponse($0) })
            .sorted(by: { lhs, rhs -> Bool in
                return lhs.date > rhs.date
            })

    }

}

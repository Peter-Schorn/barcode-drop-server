import Foundation
import Vapor
import MongoKitten
import Meow

struct Scan: Content {

    static let defaultContentType: HTTPMediaType = .urlEncodedForm

    let barcode: String

}

struct ScannedBarcode: Model, Sendable {

    @Field var _id: ObjectId
    @Field var barcode: String
    @Field var date: Date

}

struct ScannedBarcodeResponse: Content {

    static let defaultContentType: HTTPMediaType = .json

    let barcode: String
    let date: Date

    init(barcode: String, date: Date) {
        self.barcode = barcode
        self.date = date
    }

    init(_ scannedBarcode: ScannedBarcode) {
        self.barcode = scannedBarcode.barcode
        self.date = scannedBarcode.date
    }

    static func array(_ scannedBarcodes: [ScannedBarcode]) -> [ScannedBarcodeResponse] {
        return scannedBarcodes
            .map({ ScannedBarcodeResponse($0) })
            .sorted(by: { lhs, rhs -> Bool in
                return lhs.date > rhs.date
            })
    }

}

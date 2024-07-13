import Foundation
import Vapor
import MongoKitten
import Meow

/// MongoDB Model representing a scanned barcode. Used to save barcodes to the 
/// database.
struct ScannedBarcode: @unchecked Sendable, Model, Codable {

    static let collectionName = "barcodes"

    init(
        id: ObjectId? = nil, 
        barcode: String, 
        user: String? = nil, 
        date: Date
    ) {
        self._id = id ?? ObjectId()
        self.barcode = barcode
        self.user = user
        self.date = date
    }

    @Field var _id: ObjectId
    @Field var barcode: String
    @Field var user: String?
    @Field var date: Date

}

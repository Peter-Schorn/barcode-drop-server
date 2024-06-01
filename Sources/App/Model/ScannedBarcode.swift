import Foundation
import Vapor
import MongoKitten
import Meow

/// MongoDB Model representing a scanned barcode. Used to save barcodes to the 
/// database.
struct ScannedBarcode: Model, Codable, @unchecked Sendable {

    static let collectionName = "barcodes"

    @Field var _id: ObjectId
    @Field var barcode: String
    @Field var user: String?
    @Field var date: Date

}

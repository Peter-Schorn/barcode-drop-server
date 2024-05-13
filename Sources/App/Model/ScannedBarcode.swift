import Foundation
import Vapor
@preconcurrency import MongoKitten
@preconcurrency import Meow

/// MongoDB Model representing a scanned barcode. Used to save barcodes to the 
/// database.
struct ScannedBarcode: Model, Codable, @unchecked Sendable {

    @Field var _id: ObjectId
    @Field var barcode: String
    @Field var user: String?
    @Field var date: Date

}

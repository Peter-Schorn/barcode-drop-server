import Vapor
import Foundation

enum LatestScanOption: String, Codable {

    case barcodeOnly = "barcode-only"
    case json

    static let defaultValue: Self = .barcodeOnly

    init(from decoder: Decoder) throws {

        let container = try decoder.singleValueContainer()

        do {
            let string = try container.decode(String.self)
            self = Self(rawValue: string) ?? .defaultValue

        } catch let error {
            _ = error
            self = .defaultValue
            return
        }

    }

}

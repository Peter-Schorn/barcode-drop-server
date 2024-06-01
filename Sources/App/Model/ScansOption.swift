import Vapor
import Foundation

enum ScansOption: String, Sendable, Codable {

    case barcodesOnly = "barcodes-only"
    case json

    // case jsonPretty = "json-pretty"
    // case jsonMinified = "json-minified"

    static let defaultValue: Self = .json

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

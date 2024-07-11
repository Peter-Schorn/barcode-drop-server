import Vapor
import Foundation

struct GetScansQuery: Content {

    let format: ScansOption
    let prettyPrinted: Bool

    var encoder: JSONEncoder {
        return self.prettyPrinted ? 
            .sortedKeysPrettyPrinted :
            .iso8601
            
    }

    init(format: ScansOption, prettyPrinted: Bool) {
        self.format = format
        self.prettyPrinted = prettyPrinted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.format = try container.decodeIfPresent(
            ScansOption.self, forKey: .format
        ) ?? .defaultValue

        self.prettyPrinted = try container.decodeIfPresent(
            Bool.self, forKey: .prettyPrinted
        ) ?? true

    }

    private enum CodingKeys: String, CodingKey {
        case format
        case prettyPrinted = "pretty-printed"
    }

}

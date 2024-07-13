import Foundation
import Vapor
import MongoKitten
import Meow

struct SplashTextResponse: @unchecked Sendable, Content {

    static let defaultContentType = HTTPMediaType.json

    let message: String
    let id: String

    init(message: String, id: String) {
        self.message = message
        self.id = id
    }

    init(_ splashText: SplashText) {
        self.message = splashText.message
        self.id = splashText._id.hexString
    }

    init(from decoder: Decoder) throws {

        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )

        self.message = try container.decode(
            String.self, forKey: .message
        )

        self.id = try container.decode(
            String.self, forKey: .id
        )

    }

    func encode(to encoder: Encoder) throws {

        var container = encoder.container(
            keyedBy: CodingKeys.self
        )

        try container.encode(
            self.message, forKey: .message
        )

        try container.encode(
            self.id, forKey: .id
        )

    }

    private enum CodingKeys: String, CodingKey {
        case id
        case message
    }

}

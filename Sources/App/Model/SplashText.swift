import Foundation
import Vapor
import MongoKitten
import Meow

struct SplashText: @unchecked Sendable, Model, Codable {

    @Field var _id: ObjectId
    @Field var message: String

    init(id: ObjectId?, message: String) {
        self._id = id ?? ObjectId()
        self.message = message
    }

    init(_ splashTextRequestBody: SplashTextRequest) {
        self._id = splashTextRequestBody.id
            .flatMap { ObjectId($0) } ?? ObjectId()
        self.message = splashTextRequestBody.message
    }

    init(from decoder: Decoder) throws {

        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        self.message = try container.decode(
            String.self, forKey: .message
        )
        self._id = try container.decodeIfPresent(
            ObjectId.self, forKey: ._id
        ) ?? ObjectId()

    }

    func encode(to encoder: Encoder) throws {

        var container = encoder.container(
            keyedBy: CodingKeys.self
        )
        try container.encode(
            self.message, forKey: .message
        )
        try container.encode(
            self._id, forKey: ._id
        )

    }

    private enum CodingKeys: String, CodingKey {
        case _id
        case message
    }

}

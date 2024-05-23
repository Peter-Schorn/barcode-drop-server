import Vapor
import Foundation

struct DeleteScansRequestBody: Content {
    
    let ids: [String]
    let users: [String]

    init(ids: [String] = [], users: [String] = []) throws {
        if users.isEmpty && ids.isEmpty {
            throw Abort(
                .badRequest, 
                reason: "ids and users cannot *both* be empty"
            )
        }
        self.ids = ids
        self.users = users
    }

}

extension DeleteScansRequestBody: Codable {
    
    enum CodingKeys: String, CodingKey {
        case ids
        case users
    }

    init(from decoder: Decoder) throws {
        
        var ids: [String] = []
        var users: [String] = []

        do {

            let container = try decoder.container(
                keyedBy: CodingKeys.self
            )
            
            ids = try container.decodeIfPresent(
                [String].self, forKey: .ids
            ) ?? []
            
            users = try container.decodeIfPresent(
                [String].self, forKey: .users
            ) ?? []
            

        } catch let dictionaryDecodingError  {
            print(
                """
                Error decoding DeleteScansRequestBody \
                (dictionaryDecodingError):
                \(dictionaryDecodingError)
                """
            )
            let singleValueContainer = try decoder.singleValueContainer()
            ids = try singleValueContainer.decode(
                [String].self
            )
            users = []
        }

        try self.init(
            ids: ids,
            users: users
        )

    }

    func encode(to encoder: Encoder) throws {
        
        var container = encoder.container(
            keyedBy: CodingKeys.self
        )
        
        try container.encode(
            self.ids, forKey: .ids
        )
        try container.encode(
            self.users, forKey: .users
        )

    }

}

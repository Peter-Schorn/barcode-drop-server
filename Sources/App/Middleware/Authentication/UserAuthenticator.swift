// import Vapor

// struct UserAuthenticator: AsyncRequestAuthenticator {
    
//     typealias User = App.User

//     static let password: String = {
//         guard let password = ProcessInfo.processInfo
//                 .environment["BARCODE_DROP_BACKEND_PASSWORD"] else {
//             fatalError(
//                 """
//                 could not find BARCODE_DROP_BACKEND_PASSWORD in \
//                 environment variables
//                 """
//             )
//         }
//         return password
//     }()

//     func authenticate(
//         request: Request
//     ) async throws {

//         guard let authHeader = request.headers["Authorization"].first else {
//             request.logger.error(
//                 "Authorization header not found"
//             )
//             throw Abort(.unauthorized)
//         }

//         if authHeader == Self.password {
//             request.auth.login(User(name: "Admin"))
//             request.logger.info("authenticated user 'Admin'")
//         }
//         else {
//             request.logger.error(
//                 "invalid password: '\(authHeader)'"
//             )
//             throw Abort(.unauthorized)
//         }
//     }
// }

// struct User: Authenticatable {

//     let name: String

//     init(name: String) {
//         self.name = name
//     }

//     static func authenticator() -> UserAuthenticator {
//         UserAuthenticator()
//     }

// }

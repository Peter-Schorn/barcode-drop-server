// import Foundation
// import Logging
// import Vapor
// @preconcurrency import MongoKitten

// import AWSS3
// import ClientRuntime
// import AWSElasticBeanstalk

// struct ProtectedRoutes: @unchecked Sendable, RouteCollection {

//     let elasticBeanstalkClient: ElasticBeanstalkClient
//     let backendEnvironmentID: String

//     init(
//         elasticBeanstalkClient: ElasticBeanstalkClient,
//         backendEnvironmentID: String
//     ) {
//         self.elasticBeanstalkClient = elasticBeanstalkClient
//         self.backendEnvironmentID = backendEnvironmentID
//     }

//     func boot(routes: RoutesBuilder) throws {

//         let protectedRoutes = routes.grouped(
//             User.authenticator(), 
//             User.guardMiddleware()
//         )

//         protectedRoutes.post("restart-backend", use: restartBackend)

//     }

//     @Sendable
//     func restartBackend(req: Request) async throws -> String {

//         req.logger.notice("restarting backend")

//         let request = RestartAppServerInput(
//             environmentId: self.backendEnvironmentID
//         )

//         do {

//             let result = try await self.elasticBeanstalkClient.restartAppServer(
//                 input: request
//             )

//             req.logger.notice(
//                 "restart backend result: \(result)"
//             )

//         } catch {
//             req.logger.error(
//                 "could not restart backend: \(error)"
//             )
//             throw Abort(.internalServerError)
//         }

//         return "restarting backend"

//     }

// }

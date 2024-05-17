import Vapor
import MongoKitten
import Foundation

struct ScanStreamCollection: RouteCollection {
    
    private let collection: MongoCollection

    init(collection: MongoCollection) {
        self.collection = collection
    }

    func boot(routes: RoutesBuilder) throws {
        // TODO: Convert GET /stream/:user to GET /scans/:user/tail
        // probably can't use route collection to use route I want, so use 
        // another means of encapsulating the streaming logic

        let routes = routes.grouped("stream")
        routes.get(
            ":user", 
            use: generateUserScanStream(req:)
        )

    }
    
    // Uses a change stream to watch for new scans and streams them to the 
    // client.
    func generateUserScanStream(
        req: Request
    ) async throws -> AsyncThrowingStream<String, Error> {

        // TODO: Use MongoDB change streams to watch for new scans and stream
        // TODO: to the client.

        // TODO: Add query parameter ?latest=true to only stream the latest scan
        // TODO: for the user (will be continuously replaced by the latest scan).
        let latest = req.query["latest"] == "true"

        let stream: AsyncThrowingStream<String, Error> = { 
            fatalError("not implemented") 
        }()

        return AsyncThrowingStream<String, Error> { continuation in
            Task {
                for try await element in stream {
                    continuation.yield(element)
                }

                continuation.finish(throwing: nil)
            }
        }
    }

}

extension AsyncThrowingStream: AsyncResponseEncodable where Element: Encodable {
    
    public func encodeResponse(
        for request: Request
    ) async throws -> Response {

        let response = Response(status: .ok)
        
        let body = Response.Body(stream: { writer in
            Task {
                do {
                    for try await element in self {
                        let data = try JSONEncoder().encode(element)
                        _ = writer.write(.buffer(.init(data: data)))
                    }
                    
                    _ = writer.write(.end)
                } catch {
                    // Handle errors as needed
                    print(
                        "AsyncThrowingStream.encodeResponse: error: \(error)"
                    )
                }
            }
        })

        response.body = body
        return response

    }

}

@testable import App
import XCTVapor

final class AppTests: XCTestCase {
    var app: Application!
    
    override func setUp() async throws {
        self.app = try await Application.make(.testing)
        try await configure(app) // Provide the missing argument
    }
    
    override func tearDown() async throws { 
        try await self.app.asyncShutdown()
        self.app = nil
    }
    
    func testRootEndpoint() async throws {
        try await self.app.test(.GET, "/", afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
            XCTAssert(
                res.body.string.starts(with: "success"), 
                "response did not start with 'success': '\(res.body.string)'"
            )
        })
    }
    
}

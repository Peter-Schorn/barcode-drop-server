@testable import App
import XCTVapor

final class AppTests: XCTestCase {
    var app: Application!
    
    override func setUp() async throws {
        self.app = Application(.testing)
        try await configure(app)
    }
    
    override func tearDown() async throws { 
        self.app.shutdown()
        self.app = nil
    }
    
    func testRootEndpoint() async throws {
        try self.app.test(.GET, afterResponse: { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssert(
                res.body.string.startsWith("success"), 
                "response did not start with 'success': '\(res.body.string)'"
            )
        })
    }
}

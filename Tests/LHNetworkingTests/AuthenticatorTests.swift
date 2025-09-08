import XCTest
@testable import LHNetworking

final class AuthenticatorTests: XCTestCase {
    func testBearerToken() async throws {
        let auth = BearerTokenAuthenticator(token: "abc")
        var req = URLRequest(url: URL(string: "https://example.com")!)
        req = try await auth.authenticate(req)
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer abc")
    }

    func testAPIKeyHeader() async throws {
        let auth = APIKeyHeaderAuthenticator(header: "X-API-Key", value: "k123")
        var req = URLRequest(url: URL(string: "https://example.com")!)
        req = try await auth.authenticate(req)
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-API-Key"), "k123")
    }

    func testAPIKeyQuery() async throws {
        let auth = APIKeyQueryAuthenticator(name: "api_key", value: "k123")
        var req = URLRequest(url: URL(string: "https://example.com/path?x=1")!)
        req = try await auth.authenticate(req)
        XCTAssertTrue(req.url?.absoluteString.contains("api_key=k123") == true)
        XCTAssertTrue(req.url?.absoluteString.contains("x=1") == true)
    }
}


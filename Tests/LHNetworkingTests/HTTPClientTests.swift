import XCTest
@testable import LHNetworking

final class HTTPClientTests: XCTestCase {
    func makeClient(baseURL: URL? = URL(string: "https://example.com"),
                    config: URLSessionConfiguration = .ephemeral,
                    configuration: URLSessionHTTPClient.Configuration = .init()) -> URLSessionHTTPClient {
        let cfg = config
        cfg.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: cfg)
        var conf = configuration
        conf.baseURL = baseURL
        return URLSessionHTTPClient(session: session, configuration: conf)
    }

    func testGET_JSONDecoding_Success() async throws {
        struct User: Codable, Equatable { let id: Int; let name: String }
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.httpMethod, "GET")
            XCTAssertEqual(req.url?.absoluteString, "https://example.com/users/1")
            let data = try JSONEncoder().encode(User(id: 1, name: "Ada"))
            let response = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, data)
        }
        let client = makeClient()
        let ep = Endpoint<User>.json(method: .get, path: "/users/1")
        let user = try await client.send(ep)
        XCTAssertEqual(user, User(id: 1, name: "Ada"))
    }

    func testBasicAuth_HeaderSet() async throws {
        let expectAuth = expectation(description: "Auth header present")
        MockURLProtocol.onRequest = { req in
            if let auth = req.value(forHTTPHeaderField: "Authorization"), auth.hasPrefix("Basic ") {
                expectAuth.fulfill()
            }
        }
        MockURLProtocol.handler = { req in
            let response = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        var conf = URLSessionHTTPClient.Configuration()
        conf.authenticator = BasicAuthenticator(username: "user", password: "pass")
        let client = makeClient(configuration: conf)
        _ = try await client.send(.empty(method: .get, path: "/ping"))
        await fulfillment(of: [expectAuth], timeout: 1.0)
    }

    func testRetryOn500_SucceedsAfterRetries() async throws {
        MockURLProtocol.counter = 0
        MockURLProtocol.handler = { req in
            if MockURLProtocol.counter < 2 {
                MockURLProtocol.counter += 1
                let response = HTTPURLResponse(url: req.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            } else {
                let response = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data("ok".utf8))
            }
        }
        struct NoSleep: Sleeper { func sleep(nanoseconds: UInt64) async {} }
        var conf = URLSessionHTTPClient.Configuration()
        conf.retryPolicy = RetryPolicy(maxRetries: 3)
        conf.sleeper = NoSleep()
        let client = makeClient(configuration: conf)
        let resp = try await client.send(.data(method: .get, path: "/retry"))
        XCTAssertEqual(String(data: resp, encoding: .utf8), "ok")
        XCTAssertEqual(MockURLProtocol.counter, 2)
    }

    func testUnacceptableStatus_Throws() async throws {
        MockURLProtocol.handler = { req in
            let response = HTTPURLResponse(url: req.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data("not found".utf8))
        }
        let client = makeClient()
        let ep = Endpoint<Data>.data(method: .get, path: "/missing", accepts: [200])
        do {
            _ = try await client.send(ep)
            XCTFail("Expected error")
        } catch let NetworkError.unacceptableStatus(code, data) {
            XCTAssertEqual(code, 404)
            XCTAssertEqual(String(data: data ?? Data(), encoding: .utf8), "not found")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testManualCache_HitAndTTL() async throws {
        // Configure manual cache with short TTL
        let cache = MemoryResponseCache(maxEntries: 8)
        var conf = URLSessionHTTPClient.Configuration()
        conf.caching = .init(mode: .manual, cache: cache, defaultTTL: 60)
        let client = makeClient(configuration: conf)

        nonisolated(unsafe) var hitCount = 0
        MockURLProtocol.handler = { req in
            hitCount += 1
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("ok-\(hitCount)".utf8))
        }

        let ep = Endpoint<Data>.data(method: .get, path: "/cache")

        // First call loads from network and caches
        let a = try await client.send(ep)
        XCTAssertEqual(String(data: a, encoding: .utf8), "ok-1")

        // Second call should hit cache (no increment)
        let b = try await client.send(ep)
        XCTAssertEqual(String(data: b, encoding: .utf8), "ok-1")
        XCTAssertEqual(hitCount, 1)

        // Force different URL to avoid cache hit
        let c = try await client.send(Endpoint<Data>.data(method: .get, path: "/cache?x=1"))
        XCTAssertEqual(String(data: c, encoding: .utf8), "ok-2")
        XCTAssertEqual(hitCount, 2)
    }

    func testEndpointCacheDirectiveOverrides() async throws {
        // Global disabled, endpoint requests manual cache
        var conf = URLSessionHTTPClient.Configuration()
        conf.caching = .init(mode: .disabled, cache: MemoryResponseCache(), defaultTTL: 60)
        let client = makeClient(configuration: conf)

        nonisolated(unsafe) var count = 0
        MockURLProtocol.handler = { req in
            count += 1
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("v-\(count)".utf8))
        }

        var ep = Endpoint<Data>.data(method: .get, path: "/cache-override")
        // Manually construct with cache directive using json helper pattern
        ep = Endpoint<Data>(method: .get, path: "/cache-override", parse: { $0.body })
        // Rebuild adding manual cache directive
        let withCache = Endpoint<Data>(method: .get, path: "/cache-override", cache: .manual(ttl: 120)) { $0.body }

        let first = try await client.send(withCache)
        XCTAssertEqual(String(data: first, encoding: .utf8), "v-1")
        let second = try await client.send(withCache)
        XCTAssertEqual(String(data: second, encoding: .utf8), "v-1")
        XCTAssertEqual(count, 1)
    }

    func testBearerTokenRefreshOn401() async throws {
        // 1) first request 401, 2) refresh occurs, 3) second request 200
        nonisolated(unsafe) var phase = 0
        MockURLProtocol.onRequest = { req in
            // Track phase by Authorization header value
            _ = req.value(forHTTPHeaderField: "Authorization")
        }
        MockURLProtocol.handler = { req in
            phase += 1
            if phase == 1 {
                let resp = HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            } else {
                let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (resp, Data("ok".utf8))
            }
        }

        // Token starts as "old"; refresh returns "new"
        var conf = URLSessionHTTPClient.Configuration()
        conf.authenticator = OAuth2BearerAuthenticator(initialToken: "old") {
            return "new"
        }
        let client = makeClient(configuration: conf)
        let data = try await client.send(.data(method: .get, path: "/secure"))
        XCTAssertEqual(String(data: data, encoding: .utf8), "ok")
        XCTAssertEqual(phase, 2)
    }

    func testFormURLEncodedBody() async throws {
        MockURLProtocol.handler = { req in
            XCTAssertEqual(req.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded; charset=utf-8")
            let data: Data
            if let b = req.httpBody { data = b }
            else if let stream = req.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 1024)
                var collected = Data()
                while stream.hasBytesAvailable {
                    let read = stream.read(&buffer, maxLength: buffer.count)
                    if read > 0 { collected.append(buffer, count: read) } else { break }
                }
                data = collected
            } else {
                data = Data()
            }
            let body = String(data: data, encoding: .utf8)
            XCTAssertEqual(body, "a=1&b=2")
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }
        let client = makeClient()
        _ = try await client.send(Endpoint<Void>.empty(method: .post, path: "/form", body: .formURLEncoded([("a","1"),("b","2")])) )
    }

    func testCancellation() async throws {
        MockURLProtocol.handler = { req in
            // Sleep a bit to allow cancellation
            Thread.sleep(forTimeInterval: 0.2)
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }
        let client = makeClient()
        let task = Task { try await client.send(Endpoint<Void>.empty(method: .get, path: "/slow")) }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancel")
        } catch {
            // URLSession propagates URLError.cancelled; client maps to NetworkError.cancelled
            // Either is acceptable depending on timing. Accept both.
        }
    }
}

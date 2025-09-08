# LHNetworking Usage Guide (UIKit)

This package is UI‑framework agnostic and works equally well with UIKit. No SwiftUI dependencies are used.

## Install

Add to your Package.swift dependencies and target:

```swift
.package(url: "https://github.com/lewishalliday/LHNetworking.git", from: "0.1.0")
```

## Create a Client

```swift
import LHNetworking

let baseURL = URL(string: "https://api.example.com")!
let client = URLSessionHTTPClient(
    configuration: .init(
        baseURL: baseURL,
        retryPolicy: RetryPolicy(maxRetries: 3)
    )
)
```

## Define Models and Endpoints

```swift
struct User: Codable { let id: Int; let name: String }

// GET /users/1 -> User
let getUser = Endpoint<User>.json(method: .get, path: "/users/1")

// POST /users with JSON body -> User
struct NewUser: Encodable { let name: String }
let createUser = try Endpoint<User>.json(
    method: .post,
    path: "/users",
    body: RequestBody.json(NewUser(name: "Ada"))
)
```

## Call From UIKit (e.g., in a view controller)

```swift
final class UsersViewController: UIViewController {
    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        Task { [weak self] in
            do {
                let user = try await self?.client.send(getUser)
                await MainActor.run { self?.title = user?.name }
            } catch let NetworkError.unacceptableStatus(code, data) {
                let message = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                await MainActor.run { self?.showError("HTTP \(code): \(message)") }
            } catch {
                await MainActor.run { self?.showError("\(error)") }
            }
        }
    }

    private func showError(_ text: String) {
        let alert = UIAlertController(title: "Error", message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
```

## Query Params, Headers, and Void/Data Responses

```swift
// GET with query and custom header -> Data
let search = Endpoint<Data>.data(
    method: .get,
    path: "/search",
    query: [("q", "swift"), ("page", "1")],
    headers: HTTPHeaders([("accept", "application/json")])
)

// DELETE with no expected body
let deleteUser = Endpoint<Void>.empty(method: .delete, path: "/users/1")
```

## Request Bodies

```swift
// JSON body from Encodable
let body = try RequestBody.json(NewUser(name: "Ada"))

// Raw data with explicit content type
let raw = RequestBody.data(Data("hello".utf8), contentType: "text/plain; charset=utf-8")

// x-www-form-urlencoded
let form = RequestBody.formURLEncoded([("a","1"),("b","2")])
```

## Authentication

```swift
// Basic auth
let basic = URLSessionHTTPClient(configuration: .init(
    baseURL: baseURL,
    authenticator: BasicAuthenticator(username: "user", password: "pass")
))

// Bearer token (static)
let bearer = URLSessionHTTPClient(configuration: .init(
    baseURL: baseURL,
    authenticator: BearerTokenAuthenticator(token: "<token>")
))

// OAuth2 bearer with automatic refresh on 401
let oauth = URLSessionHTTPClient(configuration: .init(
    baseURL: baseURL,
    authenticator: OAuth2BearerAuthenticator(initialToken: "old") {
        // fetch new token from your auth service
        return "new-token"
    }
))

// API key (header or query)
let apiKeyHeader = URLSessionHTTPClient(configuration: .init(
    baseURL: baseURL,
    authenticator: APIKeyHeaderAuthenticator(header: "X-API-Key", value: "k123")
))
let apiKeyQuery = URLSessionHTTPClient(configuration: .init(
    baseURL: baseURL,
    authenticator: APIKeyQueryAuthenticator(name: "api_key", value: "k123")
))

// Unauthenticated (default)
let openClient = URLSessionHTTPClient(configuration: .init(baseURL: baseURL))
```

## Retries and Backoff

```swift
let policy = RetryPolicy(
    maxRetries: 3,
    backoff: Backoff(initial: 0.2, multiplier: 2, maxDelay: 2.0),
    retryOnStatusCodes: [429, 500, 502, 503, 504]
)
let resilientClient = URLSessionHTTPClient(configuration: .init(
    baseURL: baseURL,
    retryPolicy: policy
))
```

## Caching

You can enable caching globally or per endpoint.

Global manual cache (in-memory TTL):

```swift
let cache = MemoryResponseCache(maxEntries: 256)
let client = URLSessionHTTPClient(configuration: .init(
    baseURL: baseURL,
    caching: .init(mode: .manual, cache: cache, defaultTTL: 300)
))
```

Per endpoint override (manual TTL or disable):

```swift
// Cache this GET for 10 minutes
let cachedUser = Endpoint<User>.json(method: .get, path: "/users/1", cache: .manual(ttl: 600))

// Disable cache for this call, regardless of global settings
let noCache = Endpoint<Data>.data(method: .get, path: "/fresh", cache: .disabled)
```

URLCache-based caching (uses HTTP cache headers):

```swift
// Configure your URLSession's URLCache and use .urlCache mode
let urlCache = URLCache(memoryCapacity: 20 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024, directory: nil)
let cfg = URLSessionConfiguration.default
cfg.urlCache = urlCache
let session = URLSession(configuration: cfg)
let client = URLSessionHTTPClient(session: session, configuration: .init(
    baseURL: baseURL,
    caching: .init(mode: .urlCache)
))
```

## Logging

```swift
struct PrintLogger: NetworkLogger {
    func logRequest(_ request: URLRequest) {
        print("➡️", request.httpMethod ?? "", request.url?.absoluteString ?? "")
    }
    func logResponse(_ response: HTTPURLResponse, data: Data) {
        print("⬅️", response.statusCode, response.url?.absoluteString ?? "")
    }
}

let clientWithLogs = URLSessionHTTPClient(configuration: .init(
    baseURL: baseURL,
    logger: PrintLogger()
))
```

## Streaming Downloads (modern OSes)

```swift
if #available(iOS 15.0, *) {
    var req = URLRequest(url: URL(string: "https://example.com/large.bin")!)
    req.httpMethod = "GET"
    let (http, bytes) = try await client.bytes(req)
    guard http.statusCode == 200 else { throw NetworkError.unacceptableStatus(code: http.statusCode, data: nil) }
    var total: Int = 0
    for try await chunk in bytes { total += chunk.count }
    print("downloaded: \(total) bytes")
}
```

## Error Handling

```swift
do {
    let user: User = try await client.send(getUser)
} catch let NetworkError.unacceptableStatus(code, data) {
    // status-based errors
} catch {
    // URLError / decoding / other
}
```

## Testing

Use a custom URLProtocol to stub responses deterministically (the package’s tests show this in `Tests/LHNetworkingTests`).

```swift
final class MockURLProtocol: URLProtocol { /* implement canInit/startLoading... */ }
let cfg = URLSessionConfiguration.ephemeral
cfg.protocolClasses = [MockURLProtocol.self]
let session = URLSession(configuration: cfg)
let client = URLSessionHTTPClient(session: session, configuration: .init(baseURL: baseURL))
```

---

Questions or want extras (TLS pinning, OSLog logger, multipart)? I can add them.

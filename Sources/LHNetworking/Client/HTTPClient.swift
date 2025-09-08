import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Abstraction for an HTTP client with async/await API.
public protocol HTTPClient: Sendable {
    /// Sends the endpoint and returns its parsed response.
    func send<Response>(_ endpoint: Endpoint<Response>) async throws -> Response

    /// Sends a pre-built `URLRequest` and returns the raw response.
    func send(_ request: URLRequest) async throws -> HTTPResponse

    /// Streams response bytes for a pre-built `URLRequest` (modern OSes only).
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *)
    func bytes(_ request: URLRequest) async throws -> (HTTPURLResponse, URLSession.AsyncBytes)
}

/// Lightweight logger protocol; default implementation is no-op.
public protocol NetworkLogger: Sendable {
    func logRequest(_ request: URLRequest)
    func logResponse(_ response: HTTPURLResponse, data: Data)
}

public struct NoOpLogger: NetworkLogger {
    public init() {}
    public func logRequest(_ request: URLRequest) {}
    public func logResponse(_ response: HTTPURLResponse, data: Data) {}
}

/// Authenticator protocol for pluggable auth strategies.
public protocol RequestAuthenticator: Sendable {
    func authenticate(_ request: URLRequest) async throws -> URLRequest
}

/// An authenticator that can refresh credentials on authentication failures (e.g., 401).
public protocol RefreshingAuthenticator: RequestAuthenticator {
    /// Attempt to refresh credentials after an authentication failure.
    /// - Returns: `true` if a refresh occurred and a retry should be attempted.
    func refreshAuthentication(response: HTTPURLResponse, data: Data?) async throws -> Bool
}

public struct NoAuth: RequestAuthenticator {
    public init() {}
    public func authenticate(_ request: URLRequest) async throws -> URLRequest { request }
}

/// Injects delays between retries; injected for testability.
public protocol Sleeper: Sendable {
    func sleep(nanoseconds: UInt64) async
}

public struct DefaultSleeper: Sleeper {
    public init() {}
    public func sleep(nanoseconds: UInt64) async {
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}

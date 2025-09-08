import Foundation

/// Bearer authenticator with built-in token refresh on 401s.
public final class OAuth2BearerAuthenticator: RefreshingAuthenticator {
    actor Store {
        var token: String
        var refreshTask: Task<String, Error>?
        init(token: String) { self.token = token }

        func current() -> String { token }

        func refresh(using closure: @escaping @Sendable () async throws -> String) async throws -> String {
            if let task = refreshTask { return try await task.value }
            let task = Task { try await closure() }
            refreshTask = task
            defer { refreshTask = nil }
            let new = try await task.value
            token = new
            return new
        }
    }

    private let store: Store
    private let refreshClosure: @Sendable () async throws -> String

    /// - Parameters:
    ///   - initialToken: Token used to authenticate requests before any refresh.
    ///   - refresh: Closure to acquire a fresh token. Called when a 401 is encountered.
    public init(initialToken: String, refresh: @escaping @Sendable () async throws -> String) {
        self.store = Store(token: initialToken)
        self.refreshClosure = refresh
    }

    public func authenticate(_ request: URLRequest) async throws -> URLRequest {
        var req = request
        let token = await store.current()
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return req
    }

    public func refreshAuthentication(response: HTTPURLResponse, data: Data?) async throws -> Bool {
        guard response.statusCode == 401 else { return false }
        _ = try await store.refresh(using: refreshClosure)
        return true
    }
}


import Foundation

/// Describes an API endpoint and how to parse its response.
public struct Endpoint<Response>: Sendable {
    public let method: HTTPMethod
    public let path: String
    public let query: [(String, String)]
    public let headers: HTTPHeaders
    public let body: RequestBody
    public let timeout: TimeInterval?
    public let parse: @Sendable (HTTPResponse) throws -> Response
    public let accepts: Set<Int>?
    public let cache: CacheDirective?

    public init(
        method: HTTPMethod,
        path: String,
        query: [(String, String)] = [],
        headers: HTTPHeaders = .init(),
        body: RequestBody = .none,
        timeout: TimeInterval? = nil,
        accepts: Set<Int>? = nil,
        cache: CacheDirective? = nil,
        parse: @escaping @Sendable (HTTPResponse) throws -> Response
    ) {
        self.method = method
        self.path = path
        self.query = query
        self.headers = headers
        self.body = body
        self.timeout = timeout
        self.accepts = accepts
        self.parse = parse
        self.cache = cache
    }
}

public extension Endpoint where Response == Void {
    static func empty(
        method: HTTPMethod,
        path: String,
        query: [(String, String)] = [],
        headers: HTTPHeaders = .init(),
        body: RequestBody = .none,
        timeout: TimeInterval? = nil,
        accepts: Set<Int>? = nil
    ) -> Endpoint<Void> {
        Endpoint(method: method, path: path, query: query, headers: headers, body: body, timeout: timeout, accepts: accepts, cache: nil) { _ in () }
    }
}

public extension Endpoint where Response == Data {
    static func data(
        method: HTTPMethod,
        path: String,
        query: [(String, String)] = [],
        headers: HTTPHeaders = .init(),
        body: RequestBody = .none,
        timeout: TimeInterval? = nil,
        accepts: Set<Int>? = nil
    ) -> Endpoint<Data> {
        Endpoint(method: method, path: path, query: query, headers: headers, body: body, timeout: timeout, accepts: accepts, cache: nil) { resp in
            resp.body
        }
    }
}

public extension Endpoint where Response: Decodable {
    static func json(
        _ type: Response.Type = Response.self,
        method: HTTPMethod,
        path: String,
        query: [(String, String)] = [],
        headers: HTTPHeaders = .init(),
        body: RequestBody = .none,
        timeout: TimeInterval? = nil,
        accepts: Set<Int>? = nil,
        decoder: JSONDecoder = JSONDecoder()
    ) -> Endpoint<Response> {
        Endpoint(method: method, path: path, query: query, headers: headers, body: body, timeout: timeout, accepts: accepts, cache: nil) { resp in
            do {
                return try decoder.decode(Response.self, from: resp.body)
            } catch {
                throw NetworkError.decodingFailed(underlying: error)
            }
        }
    }
}

/// Per-endpoint cache directive. `inherit` uses the client's configuration.
public enum CacheDirective: Sendable, Equatable {
    case inherit
    case disabled
    case urlCache
    case manual(ttl: TimeInterval)
}


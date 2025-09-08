import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// URLSession-backed implementation with async/await bridging for portability.
public final class URLSessionHTTPClient: @unchecked Sendable, HTTPClient {
    public struct Configuration: Sendable {
        public var baseURL: URL?
        public var defaultHeaders: HTTPHeaders
        public var timeout: TimeInterval
        public var cachePolicy: URLRequest.CachePolicy
        public var accepts: Set<Int>?
        public var logger: NetworkLogger
        public var retryPolicy: RetryPolicy
        public var authenticator: RequestAuthenticator
        public var sleeper: Sleeper
        public var caching: CachingConfiguration

        public init(
            baseURL: URL? = nil,
            defaultHeaders: HTTPHeaders = HTTPHeaders([("accept", "application/json")]),
            timeout: TimeInterval = 30,
            cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
            accepts: Set<Int>? = nil,
            logger: NetworkLogger = NoOpLogger(),
            retryPolicy: RetryPolicy = RetryPolicy(),
            authenticator: RequestAuthenticator = NoAuth(),
            sleeper: Sleeper = DefaultSleeper(),
            caching: CachingConfiguration = CachingConfiguration()
        ) {
            self.baseURL = baseURL
            self.defaultHeaders = defaultHeaders
            self.timeout = timeout
            self.cachePolicy = cachePolicy
            self.accepts = accepts
            self.logger = logger
            self.retryPolicy = retryPolicy
            self.authenticator = authenticator
            self.sleeper = sleeper
            self.caching = caching
        }
    }

    private let session: URLSession
    private let config: Configuration

    public init(session: URLSession = URLSession(configuration: .default), configuration: Configuration = Configuration()) {
        self.session = session
        self.config = configuration
    }

    // MARK: HTTPClient

    public func send<Response>(_ endpoint: Endpoint<Response>) async throws -> Response {
        let url = try makeURL(path: endpoint.path, query: endpoint.query)
        var request = URLRequest(url: url, cachePolicy: effectiveCachePolicy(endpoint.cache), timeoutInterval: endpoint.timeout ?? config.timeout)
        request.httpMethod = endpoint.method.rawValue
        request = try await applyCommonHeaders(to: request, extra: endpoint.headers)
        request = try await applyBody(endpoint.body, to: request)

        // Manual cache lookup only for idempotent GET/HEAD requests
        if let (shouldUseManual, ttl) = manualCacheParameters(for: endpoint.cache), shouldUseManual, isCacheableMethod(request.httpMethod) {
            if let key = CacheKey.from(request), let cached = await config.caching.cache?.get(for: key) {
                // Respect accepts if provided
                if let accepts = endpoint.accepts ?? config.accepts, !accepts.contains(cached.statusCode) {
                    // ignore cached if status not accepted
                } else {
                    config.logger.logResponse(HTTPURLResponse(url: cached.url ?? url, statusCode: cached.statusCode, httpVersion: nil, headerFields: cached.headers.dictionary) ?? HTTPURLResponse(), data: cached.body)
                    return try endpoint.parse(cached)
                }
            }
        }
        let raw = try await send(request)

        if let accepts = endpoint.accepts ?? config.accepts, !accepts.contains(raw.statusCode) {
            throw NetworkError.unacceptableStatus(code: raw.statusCode, data: raw.body)
        }
        let parsed = try endpoint.parse(raw)

        // Store in manual cache when applicable
        if let (shouldUseManual, ttl) = manualCacheParameters(for: endpoint.cache), shouldUseManual, isCacheableMethod(request.httpMethod) {
            if let key = CacheKey.from(request) {
                await config.caching.cache?.set(raw, for: key, ttl: ttl)
            }
        }

        return parsed
    }

    public func send(_ request: URLRequest) async throws -> HTTPResponse {
        var attempt = 0
        var lastError: Error?
        var didAttemptAuthRefresh = false

        while true {
            if Task.isCancelled { throw NetworkError.cancelled }

            let req = try await config.authenticator.authenticate(request)
            config.logger.logRequest(req)
            do {
                let (data, response) = try await data(for: req)
                guard let http = response as? HTTPURLResponse else { throw NetworkError.nonHTTPResponse }
                config.logger.logResponse(http, data: data)

                if http.statusCode == 401, !didAttemptAuthRefresh, let refreshable = config.authenticator as? RefreshingAuthenticator {
                    didAttemptAuthRefresh = true
                    if try await refreshable.refreshAuthentication(response: http, data: data) {
                        continue
                    }
                }
                if config.retryPolicy.shouldRetry(response: http, data: data, error: nil, attempt: attempt) {
                    attempt += 1
                    let nanos = UInt64(config.retryPolicy.backoff.delay(for: attempt) * 1_000_000_000)
                    await config.sleeper.sleep(nanoseconds: nanos)
                    continue
                }

                return HTTPResponse(response: http, data: data)
            } catch {
                if let urlError = error as? URLError, urlError.code == .cancelled {
                    throw NetworkError.cancelled
                }
                if config.retryPolicy.shouldRetry(response: nil, data: nil, error: error, attempt: attempt) {
                    lastError = error
                    attempt += 1
                    let nanos = UInt64(config.retryPolicy.backoff.delay(for: attempt) * 1_000_000_000)
                    await config.sleeper.sleep(nanoseconds: nanos)
                    continue
                }
                throw error
            }
        }
    }

    // MARK: Streaming bytes (modern OSes)

    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *)
    public func bytes(_ request: URLRequest) async throws -> (HTTPURLResponse, URLSession.AsyncBytes) {
        var attempt = 0
        var didAttemptAuthRefresh = false

        while true {
            if Task.isCancelled { throw NetworkError.cancelled }
            let req = try await config.authenticator.authenticate(request)
            config.logger.logRequest(req)
            do {
                let (bytes, response) = try await session.bytes(for: req)
                guard let http = response as? HTTPURLResponse else { throw NetworkError.nonHTTPResponse }
                // We cannot log the whole body here; log headers only via empty data marker
                config.logger.logResponse(http, data: Data())

                if http.statusCode == 401, !didAttemptAuthRefresh, let refreshable = config.authenticator as? RefreshingAuthenticator {
                    didAttemptAuthRefresh = true
                    _ = try await refreshable.refreshAuthentication(response: http, data: nil)
                    attempt = 0
                    continue
                }

                if config.retryPolicy.shouldRetry(response: http, data: nil, error: nil, attempt: attempt) {
                    attempt += 1
                    let nanos = UInt64(config.retryPolicy.backoff.delay(for: attempt) * 1_000_000_000)
                    await config.sleeper.sleep(nanoseconds: nanos)
                    continue
                }

                return (http, bytes)
            } catch {
                if let urlError = error as? URLError, urlError.code == .cancelled { throw NetworkError.cancelled }
                if config.retryPolicy.shouldRetry(response: nil, data: nil, error: error, attempt: attempt) {
                    attempt += 1
                    let nanos = UInt64(config.retryPolicy.backoff.delay(for: attempt) * 1_000_000_000)
                    await config.sleeper.sleep(nanoseconds: nanos)
                    continue
                }
                throw error
            }
        }
    }

    // MARK: Helpers

    private func makeURL(path: String, query: [(String, String)]) throws -> URL {
        if let base = config.baseURL {
            guard var components = URLComponents(url: base, resolvingAgainstBaseURL: true) else {
                throw NetworkError.invalidURL(base.absoluteString)
            }
            var p = components.path
            if !path.isEmpty {
                if p.hasSuffix("/") { p.removeLast() }
                if !path.hasPrefix("/") { p += "/" }
                p += path
            }
            components.path = p
            if !query.isEmpty {
                var items = components.queryItems ?? []
                items.append(contentsOf: query.map { URLQueryItem(name: $0.0, value: $0.1) })
                components.queryItems = items
            }
            guard let url = components.url else { throw NetworkError.invalidURL("\(base)\(path)") }
            return url
        } else {
            guard var components = URLComponents(string: path) else { throw NetworkError.invalidURL(path) }
            if !query.isEmpty {
                var items = components.queryItems ?? []
                items.append(contentsOf: query.map { URLQueryItem(name: $0.0, value: $0.1) })
                components.queryItems = items
            }
            guard let url = components.url else { throw NetworkError.invalidURL(path) }
            return url
        }
    }

    private func applyCommonHeaders(to request: URLRequest, extra: HTTPHeaders) async throws -> URLRequest {
        var req = request
        // default headers
        for (k, v) in config.defaultHeaders { req.setValue(v, forHTTPHeaderField: k) }
        // endpoint overrides
        for (k, v) in extra { req.setValue(v, forHTTPHeaderField: k) }
        return req
    }

    private func applyBody(_ body: RequestBody, to request: URLRequest) async throws -> URLRequest {
        var req = request
        switch body {
        case .none:
            return req
        case let .data(d, contentType):
            req.httpBody = d
            if let ct = contentType { req.setValue(ct, forHTTPHeaderField: "Content-Type") }
            return req
        case let .jsonData(data, contentType):
            req.httpBody = data
            req.setValue(contentType, forHTTPHeaderField: "Content-Type")
            return req
        case let .formURLEncoded(items):
            let query = items.map { key, value in
                percentEncode(key) + "=" + percentEncode(value)
            }.joined(separator: "&")
            if let d = query.data(using: .utf8) {
                req.httpBody = d
                req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            }
            return req
        }
    }

    // Percent-encode for x-www-form-urlencoded
    private func percentEncode(_ string: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=")
        return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
    }

    // MARK: Async bridging

    private func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *) {
            return try await session.data(for: request)
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                let task = session.dataTask(with: request) { data, response, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let data = data, let response = response else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                        return
                    }
                    continuation.resume(returning: (data, response))
                }
                task.resume()
            }
        }
    }

    // MARK: Caching helpers

    public struct CachingConfiguration: Sendable {
        public enum Mode: Sendable { case disabled, urlCache, manual }
        public var mode: Mode
        public var cache: ResponseCache?
        public var defaultTTL: TimeInterval
        public init(mode: Mode = .disabled, cache: ResponseCache? = nil, defaultTTL: TimeInterval = 300) {
            self.mode = mode
            self.cache = cache
            self.defaultTTL = defaultTTL
        }
    }

    private func effectiveCachePolicy(_ directive: CacheDirective?) -> URLRequest.CachePolicy {
        switch resolvedCacheMode(directive) {
        case .disabled: return .reloadIgnoringLocalCacheData
        case .urlCache: return config.cachePolicy
        case .manual:   return .reloadIgnoringLocalCacheData
        }
    }

    private func resolvedCacheMode(_ directive: CacheDirective?) -> CachingConfiguration.Mode {
        switch directive {
        case .none, .some(.inherit): return config.caching.mode
        case .some(.disabled): return .disabled
        case .some(.urlCache): return .urlCache
        case .some(.manual): return .manual
        }
    }

    private func manualCacheParameters(for directive: CacheDirective?) -> (Bool, TimeInterval)? {
        let mode = resolvedCacheMode(directive)
        guard mode == .manual else { return nil }
        switch directive {
        case .some(.manual(let ttl)): return (true, ttl)
        default: return (true, config.caching.defaultTTL)
        }
    }

    private func isCacheableMethod(_ method: String?) -> Bool {
        guard let m = method?.uppercased() else { return false }
        return m == HTTPMethod.get.rawValue || m == HTTPMethod.head.rawValue
    }
}

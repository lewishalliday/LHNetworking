import Foundation

/// Key for caching HTTP responses.
public struct CacheKey: Hashable, Sendable {
    public let method: String
    public let url: String
    public init(method: String, url: String) { self.method = method; self.url = url }

    public static func from(_ request: URLRequest) -> CacheKey? {
        guard let url = request.url?.absoluteString, let method = request.httpMethod else { return nil }
        return CacheKey(method: method, url: url)
    }
}

/// An async-safe cache for HTTP responses.
public protocol ResponseCache: Sendable {
    func get(for key: CacheKey) async -> HTTPResponse?
    func set(_ response: HTTPResponse, for key: CacheKey, ttl: TimeInterval) async
    func remove(for key: CacheKey) async
    func removeAll() async
}

/// A simple in-memory TTL cache, capped by number of entries.
public actor MemoryResponseCache: ResponseCache {
    public struct Entry: Sendable { let response: HTTPResponse; let expiry: Date }
    private var storage: [CacheKey: Entry] = [:]
    private var order: [CacheKey] = []
    private let maxEntries: Int

    public init(maxEntries: Int = 256) { self.maxEntries = max(1, maxEntries) }

    public func get(for key: CacheKey) async -> HTTPResponse? {
        guard let entry = storage[key] else { return nil }
        if entry.expiry < Date() { storage.removeValue(forKey: key); order.removeAll { $0 == key }; return nil }
        return entry.response
    }

    public func set(_ response: HTTPResponse, for key: CacheKey, ttl: TimeInterval) async {
        let expiry = Date().addingTimeInterval(ttl)
        storage[key] = Entry(response: response, expiry: expiry)
        order.removeAll { $0 == key }
        order.append(key)
        if storage.count > maxEntries {
            let removeCount = storage.count - maxEntries
            for _ in 0..<removeCount { if let k = order.first { storage.removeValue(forKey: k); order.removeFirst() } }
        }
    }

    public func remove(for key: CacheKey) async { storage.removeValue(forKey: key); order.removeAll { $0 == key } }
    public func removeAll() async { storage.removeAll(); order.removeAll() }
}


import Foundation

/// Case-insensitive HTTP headers container optimized for low overhead.
public struct HTTPHeaders: Sendable, Equatable {
    @usableFromInline
    internal var storage: [String: String] // lowercased keys

    /// Creates an empty headers container.
    public init() { self.storage = [:] }

    /// Creates a headers container from sequence of pairs.
    public init<S: Sequence>(_ elements: S) where S.Element == (String, String) {
        var dict: [String: String] = [:]
        dict.reserveCapacity(8)
        for (k, v) in elements { dict[k.lowercased()] = v }
        self.storage = dict
    }

    /// Sets a header value (overwrites existing) using a case-insensitive key.
    public subscript(_ key: String) -> String? {
        get { storage[key.lowercased()] }
        set { storage[key.lowercased()] = newValue }
    }

    /// Returns all headers as a `[String: String]` dictionary.
    public var dictionary: [String: String] { storage }

    /// Adds a value to an existing header as comma separated; creates if absent.
    public mutating func add(_ value: String, for key: String) {
        let k = key.lowercased()
        if let existing = storage[k], !existing.isEmpty {
            storage[k] = existing + ", " + value
        } else {
            storage[k] = value
        }
    }

    /// Merges another headers container, overwriting existing values.
    public mutating func merge(_ other: HTTPHeaders) {
        for (k, v) in other.storage { storage[k] = v }
    }
}

extension HTTPHeaders: Sequence {
    public func makeIterator() -> AnyIterator<(String, String)> {
        var it = storage.makeIterator()
        return AnyIterator { it.next() }
    }
}


import Foundation

/// Encapsulates request body payloads.
public enum RequestBody: Sendable {
    case none
    case data(Data, contentType: String?)
    case jsonData(Data, contentType: String)
    case formURLEncoded([(String, String)])
}

public extension RequestBody {
    /// Encodes an Encodable value to JSON data using the provided encoder.
    static func json<T: Encodable>(_ value: T, using encoder: JSONEncoder = JSONEncoder(), contentType: String = "application/json") throws -> RequestBody {
        do {
            return .jsonData(try encoder.encode(value), contentType: contentType)
        } catch {
            throw NetworkError.encodingFailed(underlying: error)
        }
    }
}

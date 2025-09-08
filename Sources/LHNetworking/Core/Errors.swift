import Foundation

/// LHNetworking error domain.
public enum NetworkError: Error, Sendable, CustomStringConvertible {
    case invalidURL(String)
    case nonHTTPResponse
    case unacceptableStatus(code: Int, data: Data?)
    case decodingFailed(underlying: Error)
    case encodingFailed(underlying: Error)
    case cancelled
    case retriedAndFailed(lastError: Error?)
    case timedOut

    public var description: String {
        switch self {
        case .invalidURL(let s): return "Invalid URL: \(s)"
        case .nonHTTPResponse: return "Response was not HTTPURLResponse"
        case .unacceptableStatus(let code, _): return "Unacceptable status code: \(code)"
        case .decodingFailed(let e): return "Decoding failed: \(e)"
        case .encodingFailed(let e): return "Encoding failed: \(e)"
        case .cancelled: return "Cancelled"
        case .retriedAndFailed(let e): return "All retries failed: \(String(describing: e))"
        case .timedOut: return "Timed out"
        }
    }
}

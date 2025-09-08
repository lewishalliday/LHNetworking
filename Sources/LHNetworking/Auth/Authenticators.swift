import Foundation

public struct BasicAuthenticator: RequestAuthenticator {
    public let username: String
    public let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    public func authenticate(_ request: URLRequest) async throws -> URLRequest {
        var req = request
        let token = Data("\(username):\(password)".utf8).base64EncodedString()
        req.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        return req
    }
}

public struct BearerTokenAuthenticator: RequestAuthenticator {
    public let tokenProvider: @Sendable () async throws -> String

    public init(token: String) {
        self.tokenProvider = { token }
    }

    public init(tokenProvider: @escaping @Sendable () async throws -> String) {
        self.tokenProvider = tokenProvider
    }

    public func authenticate(_ request: URLRequest) async throws -> URLRequest {
        var req = request
        let token = try await tokenProvider()
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return req
    }
}

public struct APIKeyHeaderAuthenticator: RequestAuthenticator {
    public let header: String
    public let valueProvider: @Sendable () async throws -> String

    public init(header: String, value: String) { self.header = header; self.valueProvider = { value } }
    public init(header: String, valueProvider: @escaping @Sendable () async throws -> String) { self.header = header; self.valueProvider = valueProvider }

    public func authenticate(_ request: URLRequest) async throws -> URLRequest {
        var req = request
        let value = try await valueProvider()
        req.setValue(value, forHTTPHeaderField: header)
        return req
    }
}

public struct APIKeyQueryAuthenticator: RequestAuthenticator {
    public let name: String
    public let valueProvider: @Sendable () async throws -> String

    public init(name: String, value: String) { self.name = name; self.valueProvider = { value } }
    public init(name: String, valueProvider: @escaping @Sendable () async throws -> String) { self.name = name; self.valueProvider = valueProvider }

    public func authenticate(_ request: URLRequest) async throws -> URLRequest {
        guard let url = request.url else { return request }
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var items = comps?.percentEncodedQueryItems ?? comps?.queryItems ?? []
        items.append(URLQueryItem(name: name, value: try await valueProvider()))
        comps?.queryItems = items
        var req = request
        req.url = comps?.url
        return req
    }
}

public struct CompositeAuthenticator: RequestAuthenticator {
    private let authenticators: [RequestAuthenticator]
    public init(_ authenticators: [RequestAuthenticator]) { self.authenticators = authenticators }
    public func authenticate(_ request: URLRequest) async throws -> URLRequest {
        var req = request
        for auth in authenticators {
            req = try await auth.authenticate(req)
        }
        return req
    }
}

#if canImport(CryptoKit)
import CryptoKit

/// Optional HMAC signer-based authenticator. Availability depends on CryptoKit.
public struct HMACAuthenticator: RequestAuthenticator {
    public enum Hash: Sendable {
        case sha256, sha512
    }

    public let key: Data
    public let header: String
    public let hash: Hash
    public let message: @Sendable (URLRequest) -> Data

    public init(key: Data, header: String = "X-Signature", hash: Hash = .sha256, message: @escaping @Sendable (URLRequest) -> Data) {
        self.key = key
        self.header = header
        self.hash = hash
        self.message = message
    }

    public func authenticate(_ request: URLRequest) async throws -> URLRequest {
        var req = request
        let msg = message(request)
        let signature: String
        switch hash {
        case .sha256:
            let key = SymmetricKey(data: key)
            let mac = HMAC<SHA256>.authenticationCode(for: msg, using: key)
            signature = Data(mac).base64EncodedString()
        case .sha512:
            let key = SymmetricKey(data: key)
            let mac = HMAC<SHA512>.authenticationCode(for: msg, using: key)
            signature = Data(mac).base64EncodedString()
        }
        req.setValue(signature, forHTTPHeaderField: header)
        return req
    }
}
#endif

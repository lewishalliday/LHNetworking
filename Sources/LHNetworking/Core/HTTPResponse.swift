import Foundation

/// A lightweight representation of an HTTP response.
public struct HTTPResponse: Sendable, Equatable {
    public let statusCode: Int
    public let headers: HTTPHeaders
    public let body: Data
    public let url: URL?

    public init(statusCode: Int, headers: HTTPHeaders, body: Data, url: URL?) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
        self.url = url
    }

    public init(response: HTTPURLResponse, data: Data) {
        var headers = HTTPHeaders()
        for (k, v) in response.allHeaderFields {
            if let k = k as? String, let v = v as? String {
                headers[k] = v
            }
        }
        self.init(statusCode: response.statusCode, headers: headers, body: data, url: response.url)
    }
}


import Foundation

final class MockURLProtocol: URLProtocol {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    nonisolated(unsafe) static var handler: Handler?
    nonisolated(unsafe) static var onRequest: (@Sendable (URLRequest) -> Void)?
    nonisolated(unsafe) static var counter: Int = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        MockURLProtocol.onRequest?(request)
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        // Nothing to clean up
    }
}

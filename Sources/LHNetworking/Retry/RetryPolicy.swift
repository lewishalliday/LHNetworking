import Foundation

/// Determines whether a request should be retried.
public struct RetryPolicy: Sendable {
    public let maxRetries: Int
    public let backoff: Backoff
    public let retryOnStatusCodes: Set<Int>
    public let retryOnURLErrorCodes: Set<URLError.Code>
    public let retryOnNetworkConnectivity: Bool

    public init(
        maxRetries: Int = 2,
        backoff: Backoff = Backoff(),
        retryOnStatusCodes: Set<Int> = [429, 500, 502, 503, 504],
        retryOnURLErrorCodes: Set<URLError.Code> = [.timedOut, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed, .notConnectedToInternet],
        retryOnNetworkConnectivity: Bool = true
    ) {
        self.maxRetries = max(0, maxRetries)
        self.backoff = backoff
        self.retryOnStatusCodes = retryOnStatusCodes
        self.retryOnURLErrorCodes = retryOnURLErrorCodes
        self.retryOnNetworkConnectivity = retryOnNetworkConnectivity
    }

    public func shouldRetry(response: HTTPURLResponse?, data: Data?, error: Error?, attempt: Int) -> Bool {
        guard attempt < maxRetries else { return false }

        if let urlError = error as? URLError {
            return retryOnURLErrorCodes.contains(urlError.code)
        }

        if let response = response {
            return retryOnStatusCodes.contains(response.statusCode)
        }

        return false
    }
}


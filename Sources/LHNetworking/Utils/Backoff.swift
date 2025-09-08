import Foundation

/// Exponential backoff with jitter for retries.
public struct Backoff: Sendable {
    public enum Jitter: Sendable { case none, full }

    public let initial: TimeInterval
    public let multiplier: Double
    public let maxDelay: TimeInterval
    public let jitter: Jitter

    public init(initial: TimeInterval = 0.2, multiplier: Double = 2.0, maxDelay: TimeInterval = 8.0, jitter: Jitter = .full) {
        self.initial = initial
        self.multiplier = multiplier
        self.maxDelay = max(0, maxDelay)
        self.jitter = jitter
    }

    public func delay(for attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        let base = min(maxDelay, initial * pow(multiplier, Double(attempt - 1)))
        switch jitter {
        case .none:
            return base
        case .full:
            let r = Double.random(in: 0...1)
            return base * r
        }
    }
}

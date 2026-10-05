import Foundation

public struct UsageAdvice: Equatable, Sendable {
    public let title: String
    public let message: String
    public static func make(snapshot: UsageSnapshot?, now: Date, failed: Bool) -> UsageAdvice? {
        guard let snapshot, !failed, !snapshot.isStale(at: now) else { return nil }
        let candidates = snapshot.windows.filter { ($0.usedPercent ?? -1) >= 80 && !$0.awaitingReset(at: now) }
        guard let window = candidates.max(by: { ($0.usedPercent ?? 0) < ($1.usedPercent ?? 0) }) else { return nil }
        let remaining = Int((window.remainingPercent ?? 0).rounded(.down))
        let wait: String
        if let reset = window.resetsAt {
            let minutes = max(1, Int(ceil(reset.timeIntervalSince(now) / 60)))
            wait = minutes < 60 ? "\(minutes) min" : minutes < 1440 ? "\(minutes / 60) hr \(minutes % 60) min" : "\(minutes / 1440) \(minutes / 1440 == 1 ? "day" : "days")"
        } else { wait = "an unconfirmed time" }
        let timing = window.resetsAt == nil ? "Reset time unavailable." : "resets in \(wait)."
        return UsageAdvice(title: "Until your reset", message: "\(remaining)% left (\(window.durationLabel)); \(timing) Try a lighter model for small tasks.")
    }
}

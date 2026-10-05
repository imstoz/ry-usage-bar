import Foundation

public struct QuotaWindow: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let usedPercent: Double?
    public let durationMinutes: Int?
    public let resetsAt: Date?
    public var remainingPercent: Double? { usedPercent.map { max(0, 100 - $0) } }
    public init(id: String, label: String, usedPercent: Double?, durationMinutes: Int?, resetsAt: Date?) {
        self.id = id; self.label = label
        self.usedPercent = usedPercent.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
        self.durationMinutes = durationMinutes.flatMap { $0 > 0 ? $0 : nil }
        self.resetsAt = resetsAt
    }
    public func awaitingReset(at now: Date) -> Bool { resetsAt.map { $0 <= now } ?? false }
    public var durationLabel: String {
        guard let m = durationMinutes else { return "Quota window" }
        if m % 10080 == 0 { return m == 10080 ? "Weekly" : "\(m / 10080) weeks" }
        if m % 1440 == 0 { return "\(m / 1440) days" }
        if m % 60 == 0 { return "\(m / 60) hours" }
        return "\(m) minutes"
    }
}
public struct UsageSnapshot: Codable, Equatable, Sendable {
    public let windows: [QuotaWindow]
    public let fetchedAt: Date
    public init(windows: [QuotaWindow], fetchedAt: Date = Date()) { self.windows = windows; self.fetchedAt = fetchedAt }
    public func isStale(at now: Date) -> Bool { now.timeIntervalSince(fetchedAt) > 600 || windows.contains { $0.awaitingReset(at: now) } }
}
public enum ParseFailure: Error { case invalidResponse, noWindows }
public enum UsageParser {
    private struct CodexResponse: Decodable { let rateLimits: Bucket?; let rateLimitsByLimitId: [String: Bucket]? }
    private struct Bucket: Decodable { let limitName: String?; let primary: Window?; let secondary: Window? }
    private struct Window: Decodable { let usedPercent: Double?; let windowDurationMins: Int?; let resetsAt: Double? }
    public static func codex(_ data: Data, now: Date = Date()) throws -> UsageSnapshot {
        let response = try JSONDecoder().decode(CodexResponse.self, from: data)
        let buckets: [String: Bucket]
        if let mapped = response.rateLimitsByLimitId, !mapped.isEmpty { buckets = mapped }
        else if let legacy = response.rateLimits { buckets = ["codex": legacy] }
        else { throw ParseFailure.noWindows }
        var windows: [QuotaWindow] = []
        for key in buckets.keys.sorted() {
            let bucket = buckets[key]!
            for (slot, value) in [("primary", bucket.primary), ("secondary", bucket.secondary)] {
                guard let value else { continue }
                windows.append(QuotaWindow(id: "\(key)/\(slot)", label: bucket.limitName ?? key, usedPercent: value.usedPercent, durationMinutes: value.windowDurationMins, resetsAt: value.resetsAt.map(Date.init(timeIntervalSince1970:))))
            }
        }
        guard !windows.isEmpty else { throw ParseFailure.noWindows }
        return UsageSnapshot(windows: windows, fetchedAt: now)
    }
    public static func claude(_ data: Data, now: Date = Date()) throws -> UsageSnapshot {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ParseFailure.invalidResponse }
        let windows = object.keys.sorted().compactMap { key -> QuotaWindow? in
            guard key == "five_hour" || key.hasPrefix("seven_day"), let raw = object[key] as? [String: Any] else { return nil }
            let reset = raw["resets_at"] as? String
            let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let date = reset.flatMap { formatter.date(from: $0) ?? ISO8601DateFormatter().date(from: $0) }
            return QuotaWindow(id: key, label: key == "five_hour" ? "Session" : key.replacingOccurrences(of: "seven_day", with: "Weekly").replacingOccurrences(of: "_", with: " "), usedPercent: (raw["utilization"] as? NSNumber)?.doubleValue, durationMinutes: key == "five_hour" ? 300 : 10080, resetsAt: date)
        }
        guard !windows.isEmpty else { throw ParseFailure.noWindows }
        return UsageSnapshot(windows: windows, fetchedAt: now)
    }
}

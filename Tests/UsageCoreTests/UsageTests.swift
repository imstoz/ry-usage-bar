#if RY_STANDALONE_TESTS
import Foundation
class XCTestCase {}
func XCTAssertEqual<T: Equatable>(_ a: T, _ b: T, file: StaticString = #file, line: UInt = #line) { precondition(a == b, "Expected equality", file: file, line: line) }
func XCTAssertNil<T>(_ value: T?, file: StaticString = #file, line: UInt = #line) { precondition(value == nil, "Expected nil", file: file, line: line) }
func XCTAssertNotNil<T>(_ value: T?, file: StaticString = #file, line: UInt = #line) { precondition(value != nil, "Expected value", file: file, line: line) }
func XCTAssertTrue(_ value: Bool, file: StaticString = #file, line: UInt = #line) { precondition(value, "Expected true", file: file, line: line) }
func XCTAssertThrowsError<T>(_ action: @autoclosure () throws -> T, file: StaticString = #file, line: UInt = #line) { do { _ = try action(); preconditionFailure("Expected error", file: file, line: line) } catch {} }
#else
import XCTest
#endif
@testable import UsageCore

final class UsageTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    func testCodexPrefersMultiBucketAndRetainsEqualDurations() throws {
        let data = Data(#"{"rateLimits":{"primary":{"usedPercent":99,"windowDurationMins":300}},"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":20,"windowDurationMins":300}},"other":{"primary":{"usedPercent":70,"windowDurationMins":300}}}}"#.utf8)
        let result = try UsageParser.codex(data, now: now)
        XCTAssertEqual(result.windows.count, 2)
        XCTAssertEqual(result.windows.map(\.usedPercent), [20, 70])
        XCTAssertEqual(Set(result.windows.map(\.id)).count, 2)
    }
    func testUnknownClaudeIsNotZero() throws {
        let result = try UsageParser.claude(Data(#"{"five_hour":{"resets_at":null},"seven_day":null}"#.utf8))
        XCTAssertNil(result.windows[0].usedPercent)
        XCTAssertNil(result.windows[0].remainingPercent)
    }
    func testMissingCodexDurationRetainsUsage() throws {
        let result = try UsageParser.codex(Data(#"{"rateLimits":{"primary":{"usedPercent":43}}}"#.utf8))
        XCTAssertEqual(result.windows[0].remainingPercent, 57)
        XCTAssertEqual(result.windows[0].durationLabel, "Quota window")
    }
    func testOverQuotaAndInvalidNumbers() {
        XCTAssertEqual(window(used: 112).remainingPercent, 0)
        XCTAssertNil(window(used: -2).usedPercent)
        XCTAssertNil(window(used: .nan).usedPercent)
    }
    func testResetDoesNotInventNewQuota() {
        let snapshot = UsageSnapshot(windows: [window(used: 90, reset: now.addingTimeInterval(-1))], fetchedAt: now)
        XCTAssertTrue(snapshot.isStale(at: now))
        XCTAssertEqual(snapshot.windows[0].remainingPercent, 10)
        XCTAssertNil(UsageAdvice.make(snapshot: snapshot, now: now, failed: false))
    }
    func testAdviceOnlyForFreshHighUsage() {
        let snapshot = UsageSnapshot(windows: [window(used: 84, reset: now.addingTimeInterval(5400))], fetchedAt: now)
        let advice = UsageAdvice.make(snapshot: snapshot, now: now, failed: false)
        XCTAssertTrue(advice?.message.contains("16% left") == true)
        XCTAssertTrue(advice?.message.contains("1 hr 30 min") == true)
        XCTAssertNil(UsageAdvice.make(snapshot: snapshot, now: now, failed: true))
        XCTAssertNil(UsageAdvice.make(snapshot: snapshot, now: now.addingTimeInterval(601), failed: false))
        XCTAssertNil(UsageAdvice.make(snapshot: UsageSnapshot(windows: [window(used: 79)], fetchedAt: now), now: now, failed: false))
    }
    func testClaudeIncludesModelWindowsAndFractionalDates() throws {
        let result = try UsageParser.claude(Data(#"{"five_hour":{"utilization":25,"resets_at":"2027-01-01T12:00:00.123Z"},"seven_day_sonnet":{"utilization":80},"extra_usage":{"utilization":20}}"#.utf8))
        XCTAssertEqual(result.windows.count, 2)
        XCTAssertNotNil(result.windows.first?.resetsAt)
    }
    func testMalformedAndEmptyResponsesFail() {
        XCTAssertThrowsError(try UsageParser.codex(Data("{}".utf8)))
        XCTAssertThrowsError(try UsageParser.claude(Data("[]".utf8)))
        XCTAssertThrowsError(try UsageParser.codex(Data(#"{"rateLimits":{"primary":{"usedPercent":"unknown"}}}"#.utf8)))
    }
    func testCachePreservesTimestamp() throws {
        let snapshot = UsageSnapshot(windows: [window(used: 21)], fetchedAt: now)
        let restored = try JSONDecoder().decode(UsageSnapshot.self, from: JSONEncoder().encode(snapshot))
        XCTAssertEqual(snapshot, restored)
        XCTAssertTrue(restored.isStale(at: now.addingTimeInterval(601)))
    }
    private func window(used: Double, reset: Date? = nil) -> QuotaWindow {
        QuotaWindow(id: "test", label: "Session", usedPercent: used, durationMinutes: 300, resetsAt: reset)
    }
}

import Foundation
@main struct CoreTestMain {
    static func main() throws {
        let suite = UsageTests()
        try suite.testCodexPrefersMultiBucketAndRetainsEqualDurations()
        try suite.testUnknownClaudeIsNotZero()
        try suite.testMissingCodexDurationRetainsUsage()
        suite.testOverQuotaAndInvalidNumbers()
        suite.testResetDoesNotInventNewQuota()
        suite.testAdviceOnlyForFreshHighUsage()
        try suite.testClaudeIncludesModelWindowsAndFractionalDates()
        suite.testMalformedAndEmptyResponsesFail()
        try suite.testCachePreservesTimestamp()
        print("Passed 9 quota, freshness and advice regression tests.")
    }
}

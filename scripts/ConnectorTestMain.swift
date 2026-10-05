import Foundation
import UsageCore
import Darwin

@main struct ConnectorTestMain {
    static func main() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ry connector tests \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let mock = directory.appendingPathComponent("mock codex")
        let script = #"""
        #!/bin/bash
        set -eu
        [[ "$1" == "app-server" ]]
        [[ "$2" == "--listen" ]]
        [[ "$3" == "stdio://" ]]
        [[ "$CODEX_HOME" == */"test home" ]]
        IFS= read -r message
        [[ "$message" == *'initialize'* ]]
        printf '%s\n' '{"id":1,"result":{}}'
        IFS= read -r message
        [[ "$message" == *'initialized'* ]]
        IFS= read -r message
        [[ "$message" == *'account/rateLimits/read'* ]]
        printf '%s\n' '{"id":2,"result":{"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":84,"windowDurationMins":300}}}}}'
        IFS= read -r message || true
        """#
        try script.write(to: mock, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: mock.path)
        let profile = Profile(name: "Test", provider: .codex, home: directory.appendingPathComponent("test home").path, executable: mock.path)
        let snapshot = try await CodexClient.fetch(profile)
        precondition(snapshot.windows[0].remainingPercent == 16)
        print("Passed process handshake, home forwarding and paths with spaces.")
        let stalled = "#!/bin/bash\nwhile IFS= read -r message; do :; done\n"
        try stalled.write(to: mock, atomically: true, encoding: .utf8)
        let started = Date()
        do { _ = try await CodexClient.fetch(profile, timeoutSeconds: 0.3); preconditionFailure("Expected timeout") }
        catch { precondition(Date().timeIntervalSince(started) < 3) }
        print("Passed stalled-process deadline and cleanup.")
        let refused = "#!/bin/bash\nIFS= read -r message\nprintf '%s\\n' '{\"id\":1,\"error\":{\"code\":-1}}'\n"
        try refused.write(to: mock, atomically: true, encoding: .utf8)
        do { _ = try await CodexClient.fetch(profile); preconditionFailure("Expected handshake failure") }
        catch ConnectionError.protocolError { print("Passed failed-initialisation handling.") }
    }
}

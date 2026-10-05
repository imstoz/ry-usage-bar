import Foundation

@main struct PortalTestMain {
    static func main() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ry portal tests \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let helpers = directory.appendingPathComponent("Library/Application Support/Claude/claude-code")
        for version in ["2.1.9", "2.1.10"] {
            let executable = helpers.appendingPathComponent("\(version)/build/claude.app/Contents/MacOS/claude")
            try FileManager.default.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("#!/bin/bash\nexit 0\n".utf8).write(to: executable)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        }
        precondition(ExecutableDiscovery.desktopClaude(userHome: directory)?.contains("/2.1.10/") == true)
        precondition(ExecutableDiscovery.desktopClaude(userHome: directory.appendingPathComponent("missing")) == nil)
        print("Passed desktop Claude helper discovery, numeric version selection and missing installation.")
        let mock = directory.appendingPathComponent("mock provider")
        func write(_ script: String) throws { try script.write(to: mock, atomically: true, encoding: .utf8); try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: mock.path) }
        let profile = Profile(name: "Test", provider: .codex, home: directory.path, executable: mock.path)
        try write(#"""
        #!/bin/bash
        set -eu
        IFS= read -r line
        [[ "$line" == *'initialize'* ]]
        printf '%s\n' '{"id":1,"result":{}}'
        IFS= read -r line
        [[ "$line" == *'initialized'* ]]
        IFS= read -r line
        [[ "$line" == *'account/login/start'* ]]
        [[ "$line" == *'chatgpt'* ]]
        printf '%s\n' '{"id":2,"result":{"loginId":"test-id","authUrl":"https://auth.openai.com/test"}}'
        printf '%s\n' '{"method":"account/login/completed","params":{"loginId":"other-id","success":false}}'
        printf '%s\n' '{"method":"account/login/completed","params":{"loginId":"test-id","success":true}}'
        IFS= read -r line || true
        """#)
        let seen = URLRecorder()
        try PortalClient.run(profile: profile, control: LoginProcess(), timeoutSeconds: 2) { seen.record($0) }
        precondition(seen.urls == [URL(string: "https://auth.openai.com/test")!])
        print("Passed browser-flow handshake and matching completion id.")
        precondition(PortalClient.permittedURL("https://auth.openai.com.evil.example/login", provider: .codex) == nil)
        precondition(PortalClient.permittedURL("http://auth.openai.com/login", provider: .codex) == nil)
        precondition(PortalClient.permittedURL("https://user:pass@claude.ai/login", provider: .claude) == nil)
        precondition(PortalClient.permittedURL("https://claude.ai/login", provider: .claude) != nil)
        print("Passed portal address validation.")
        try write("#!/bin/bash\nwhile IFS= read -r line; do :; done\n")
        let start = Date()
        do { try PortalClient.run(profile: profile, control: LoginProcess(), timeoutSeconds: 0.3) { _ in }; preconditionFailure("Expected timeout") } catch { precondition(Date().timeIntervalSince(start) < 3) }
        print("Passed sign-in timeout cleanup.")
        let cancelled = LoginProcess(); cancelled.stop()
        do { try PortalClient.run(profile: profile, control: cancelled) { _ in }; preconditionFailure("Expected cancellation") } catch is CancellationError {}
        print("Passed cancellation before process launch.")
        try write(#"""
        #!/bin/bash
        set -eu
        [[ "$1" == 'auth' && "$2" == 'login' ]]
        printf '%s\n' 'https://claude.ai/oauth/authorize?test=1'
        IFS= read -r code
        [[ "$code" == 'test-code' ]]
        """#)
        let claude = Profile(name: "Claude test", provider: .claude, home: directory.path, executable: mock.path)
        let control = LoginProcess()
        try PortalClient.run(profile: claude, control: control, timeoutSeconds: 2) { _ in try! control.submit("test-code") }
        print("Passed Claude portal address and optional code handoff.")
    }
}
final class URLRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [URL] = []
    func record(_ url: URL) { lock.lock(); defer { lock.unlock() }; stored.append(url) }
    var urls: [URL] { lock.lock(); defer { lock.unlock() }; return stored }
}

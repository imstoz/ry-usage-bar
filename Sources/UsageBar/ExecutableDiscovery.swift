import Foundation

enum ExecutableDiscovery {
    static func find(_ provider: Provider, userHome: URL = FileManager.default.homeDirectoryForCurrentUser) -> String {
        let candidates: [String]
        if provider == .codex {
            candidates = [userHome.appendingPathComponent(".local/bin/codex").path, "/opt/homebrew/bin/codex", "/usr/local/bin/codex", "/Applications/Codex.app/Contents/Resources/codex", "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"]
        } else {
            candidates = [userHome.appendingPathComponent(".local/bin/claude").path, "/opt/homebrew/bin/claude", "/usr/local/bin/claude"]
        }
        if let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) { return path }
        guard provider == .claude else { return "" }
        return desktopClaude(userHome: userHome) ?? ""
    }
    static func desktopClaude(userHome: URL) -> String? {
        // Search only the native Mac helper directory, never the Linux VM binary.
        let root = userHome.appendingPathComponent("Library/Application Support/Claude/claude-code")
        let manager = FileManager.default
        let versions = (try? manager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        for version in versions.sorted(by: { $0.lastPathComponent.compare($1.lastPathComponent, options: .numeric) == .orderedDescending }) {
            let builds = (try? manager.contentsOfDirectory(at: version, includingPropertiesForKeys: nil)) ?? []
            for build in builds.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let executable = build.appendingPathComponent("claude.app/Contents/MacOS/claude").path
                if manager.isExecutableFile(atPath: executable) { return executable }
            }
        }
        return nil
    }
}

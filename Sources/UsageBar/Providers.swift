import Foundation
import Security
import Darwin
import UsageCore

enum Provider: String, Codable, CaseIterable { case codex = "Codex", claude = "Claude" }
struct Profile: Codable, Identifiable {
    var id = UUID()
    var name: String
    var provider: Provider
    var home: String
    var executable: String
}
enum ConnectionError: LocalizedError {
    case missingCLI, timedOut, protocolError, signIn, denied, network, invalidData, rateLimited
    var errorDescription: String? {
        switch self {
        case .missingCLI: return "Choose the Codex executable in account settings."
        case .timedOut: return "The provider took too long. Try refreshing."
        case .protocolError: return "Codex could not return usage. Check the CLI version and sign in again."
        case .signIn: return "Sign in using the provider’s CLI, then refresh."
        case .denied: return "Keychain access was unavailable. Allow access or sign in to Claude Code again."
        case .network: return "Unable to reach the provider. Check your connection."
        case .invalidData: return "The provider returned an unsupported response."
        case .rateLimited: return "The provider asked us to wait. Refresh again later."
        }
    }
}
// One bounded process per refresh. No shell interpolation, account switching or inference.
struct CodexClient {
    static func fetch(_ profile: Profile, timeoutSeconds: Double = 20) async throws -> UsageSnapshot {
        try await Task.detached(priority: .utility) { try read(profile, timeoutSeconds: timeoutSeconds) }.value
    }
    private static func read(_ profile: Profile, timeoutSeconds: Double) throws -> UsageSnapshot {
        guard FileManager.default.isExecutableFile(atPath: profile.executable) else { throw ConnectionError.missingCLI }
        let process = Process(); let input = Pipe(); let output = Pipe()
        process.executableURL = URL(fileURLWithPath: profile.executable)
        process.arguments = ["app-server", "--listen", "stdio://", "-c", "analytics.enabled=false"]
        var env = ProcessInfo.processInfo.environment
        env["CODEX_HOME"] = NSString(string: profile.home).expandingTildeInPath
        process.environment = env; process.standardInput = input; process.standardOutput = output; process.standardError = FileHandle.nullDevice
        try process.run()
        let timeout = DispatchWorkItem { if process.isRunning { kill(process.processIdentifier, SIGKILL) } }
        DispatchQueue.global().asyncAfter(deadline: .now() + max(0.1, timeoutSeconds), execute: timeout)
        defer {
            try? input.fileHandleForWriting.close()
            if process.isRunning { process.terminate() }
            // Keep the deadline active until exit so a stuck provider cannot survive cleanup.
            process.waitUntilExit()
            timeout.cancel()
            try? output.fileHandleForReading.close()
        }
        func send(_ message: [String: Any]) throws {
            var data = try JSONSerialization.data(withJSONObject: message); data.append(10)
            try input.fileHandleForWriting.write(contentsOf: data)
        }
        try send(["id": 1, "method": "initialize", "params": ["clientInfo": ["name": "ry_usage_bar", "title": "ry Usage Bar", "version": "0.1.3"]]])
        var buffer = Data(); var initialised = false; var bytes = 0
        while true {
            let chunk = output.fileHandleForReading.availableData
            guard !chunk.isEmpty else { throw ConnectionError.timedOut }
            bytes += chunk.count; guard bytes < 2_000_000 else { throw ConnectionError.protocolError }
            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: 10) {
                let line = buffer.prefix(upTo: newline); buffer.removeSubrange(...newline)
                guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
                if (object["id"] as? Int) == 1 && !initialised {
                    guard object["result"] != nil else { throw ConnectionError.protocolError }
                    initialised = true
                    try send(["method": "initialized"])
                    try send(["id": 2, "method": "account/rateLimits/read"])
                } else if (object["id"] as? Int) == 2 {
                    guard let result = object["result"] as? [String: Any] else { throw ConnectionError.protocolError }
                    return try UsageParser.codex(JSONSerialization.data(withJSONObject: result))
                } else if object["id"] != nil && object["method"] != nil {
                    try send(["id": object["id"]!, "error": ["code": -32601, "message": "Usage Bar supports usage reads only"]])
                }
            }
        }
    }
}
struct ClaudeClient {
    static func fetch(_ profile: Profile) async throws -> UsageSnapshot {
        let token = try await Task.detached(priority: .utility) { try accessToken(profile) }.value
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        let config = URLSessionConfiguration.ephemeral; config.httpCookieStorage = nil
        let session = URLSession(configuration: config, delegate: NoRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let data: Data; let response: URLResponse
        do { (data, response) = try await session.data(for: request) } catch { throw ConnectionError.network }
        switch (response as? HTTPURLResponse)?.statusCode {
        case 200: return try UsageParser.claude(data)
        case 401, 403: throw ConnectionError.signIn
        case 429: throw ConnectionError.rateLimited
        default: throw ConnectionError.network
        }
    }
    private static func accessToken(_ profile: Profile) throws -> String {
        // Custom homes use the CLI-owned credentials file. We never rewrite it.
        let file = URL(fileURLWithPath: NSString(string: profile.home).expandingTildeInPath).appendingPathComponent(".credentials.json")
        var data: Data?
        if FileManager.default.fileExists(atPath: file.path) { data = try Data(contentsOf: file) }
        else if NSString(string: profile.home).expandingTildeInPath == FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude").path {
            var result: CFTypeRef?
            let status = SecItemCopyMatching([kSecClass: kSecClassGenericPassword, kSecAttrService: "Claude Code-credentials", kSecMatchLimit: kSecMatchLimitOne, kSecReturnData: true] as CFDictionary, &result)
            guard status == errSecSuccess else { throw ConnectionError.denied }
            data = result as? Data
        }
        guard let data, let root = try JSONSerialization.jsonObject(with: data) as? [String: Any], let oauth = root["claudeAiOauth"] as? [String: Any], let token = oauth["accessToken"] as? String, !token.isEmpty else { throw ConnectionError.signIn }
        return token
    }
}
private final class NoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

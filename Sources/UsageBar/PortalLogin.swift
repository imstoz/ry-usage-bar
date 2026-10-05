import AppKit
import SwiftUI
import Foundation
import Darwin

// Owns only the login subprocess, never provider credentials.
final class LoginProcess: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var input: FileHandle?
    private var cancelled = false
    func install(_ process: Process, input: FileHandle) throws {
        lock.lock(); defer { lock.unlock() }
        guard !cancelled else { throw CancellationError() }
        self.process = process; self.input = input
        try process.run()
    }
    func stop() {
        lock.lock(); defer { lock.unlock() }
        cancelled = true
        if let process, process.isRunning { kill(process.processIdentifier, SIGKILL) }
        try? input?.close()
    }
    func submit(_ code: String) throws {
        lock.lock(); defer { lock.unlock() }
        guard !cancelled, let input else { throw CancellationError() }
        try input.write(contentsOf: Data((code + "\n").utf8))
    }
}
enum PortalFailure: LocalizedError {
    case missingExecutable, rejected, timedOut, invalidURL
    var errorDescription: String? {
        switch self {
        case .missingExecutable: return "Install the provider’s CLI, or choose its executable under Advanced."
        case .rejected: return "Sign-in did not finish. Update the provider’s CLI and try again."
        case .timedOut: return "Sign-in timed out. Please try again."
        case .invalidURL: return "The provider returned an unrecognised sign-in address. Update its CLI and try again."
        }
    }
}
struct PortalClient {
    static func permittedURL(_ string: String, provider: Provider) -> URL? {
        guard let url = URL(string: string), url.scheme == "https", let host = url.host?.lowercased(), url.user == nil, url.password == nil else { return nil }
        let allowed = provider == .codex ? ["auth.openai.com", "chatgpt.com", "auth.chatgpt.com"] : ["claude.ai", "console.anthropic.com", "platform.claude.com"]
        return allowed.contains(host) ? url : nil
    }
    static func run(profile: Profile, control: LoginProcess, timeoutSeconds: Double = 600, opened: @escaping @Sendable (URL) -> Void) throws {
        guard FileManager.default.isExecutableFile(atPath: profile.executable) else { throw PortalFailure.missingExecutable }
        let process = Process(), input = Pipe(), output = Pipe()
        process.executableURL = URL(fileURLWithPath: profile.executable)
        process.arguments = profile.provider == .codex ? ["app-server", "--listen", "stdio://", "-c", "analytics.enabled=false"] : ["auth", "login", "--claudeai"]
        var env = ProcessInfo.processInfo.environment
        let home = NSString(string: profile.home).expandingTildeInPath
        if profile.provider == .codex { env["CODEX_HOME"] = home }
        else {
            // Default Claude home uses its default Keychain service; no alternate config env.
            env.removeValue(forKey: "CLAUDE_CONFIG_DIR")
            for key in ["ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "CLAUDE_CODE_OAUTH_TOKEN"] { env.removeValue(forKey: key) }
        }
        env["PATH"] = "\(FileManager.default.homeDirectoryForCurrentUser.path)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        process.environment = env; process.currentDirectoryURL = URL(fileURLWithPath: home)
        process.standardInput = input; process.standardOutput = output
        process.standardError = profile.provider == .claude ? output : FileHandle.nullDevice
        try control.install(process, input: input.fileHandleForWriting)
        let deadline = DispatchWorkItem { control.stop() }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeoutSeconds, execute: deadline)
        defer { control.stop(); process.waitUntilExit(); deadline.cancel(); try? output.fileHandleForReading.close() }
        func send(_ object: [String: Any]) throws {
            var data = try JSONSerialization.data(withJSONObject: object); data.append(10)
            try input.fileHandleForWriting.write(contentsOf: data)
        }
        if profile.provider == .codex {
            try send(["id": 1, "method": "initialize", "params": ["clientInfo": ["name": "ry_usage_bar", "title": "ry Usage Bar", "version": "0.1.3"]]])
        }
        let started = Date()
        var pending = Data(), bytes = 0, loginID: String?, initialised = false, openedURLs = Set<String>()
        while true {
            let data = output.fileHandleForReading.availableData
            if data.isEmpty {
                process.waitUntilExit()
                if profile.provider == .claude && process.terminationReason == .exit && process.terminationStatus == 0 { return }
                if Date().timeIntervalSince(started) >= timeoutSeconds { throw PortalFailure.timedOut }
                throw PortalFailure.rejected
            }
            bytes += data.count; guard bytes <= 2_000_000 else { throw PortalFailure.rejected }
            pending.append(data)
            if profile.provider == .claude {
                // The CLI owns OAuth and normally opens the browser itself. Its printed URL
                // is also offered in our window for systems where automatic opening fails.
                guard let end = pending.lastIndex(of: 10) else { continue }
                let text = String(decoding: pending.prefix(through: end), as: UTF8.self)
                let pattern = #"https://[^\s\x1B<>\"']+"#
                let regex = try NSRegularExpression(pattern: pattern)
                for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                    guard let range = Range(match.range, in: text), let url = permittedURL(String(text[range]), provider: .claude), openedURLs.insert(url.absoluteString).inserted else { continue }
                    opened(url)
                }
                continue
            }
            while let index = pending.firstIndex(of: 10) {
                let line = pending.prefix(upTo: index); pending.removeSubrange(...index)
                guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
                if object["id"] as? Int == 1 && !initialised {
                    guard object["result"] != nil else { throw PortalFailure.rejected }
                    initialised = true
                    try send(["method": "initialized"])
                    try send(["id": 2, "method": "account/login/start", "params": ["type": "chatgpt"]])
                } else if object["id"] as? Int == 2 {
                    guard let result = object["result"] as? [String: Any], let id = result["loginId"] as? String, let address = result["authUrl"] as? String else { throw PortalFailure.rejected }
                    guard let url = permittedURL(address, provider: .codex) else { throw PortalFailure.invalidURL }
                    loginID = id; opened(url)
                } else if object["method"] as? String == "account/login/completed" {
                    guard let params = object["params"] as? [String: Any], let expected = loginID, params["loginId"] as? String == expected else { continue }
                    guard params["success"] as? Bool == true else { throw PortalFailure.rejected }
                    return
                } else if object["id"] != nil && object["method"] != nil {
                    try send(["id": object["id"]!, "error": ["code": -32601, "message": "Unsupported during sign-in"]])
                }
            }
        }
    }
}

@MainActor final class PortalLogin: NSObject, ObservableObject {
    @Published var running = false
    @Published var message = "Finish signing in on the provider’s website."
    @Published var url: URL?
    @Published var provider = Provider.codex
    @Published var code = ""
    private var control: LoginProcess?
    private var task: Task<Void, Never>?
    private var window: NSWindow?
    private var sessionID = UUID()
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(appWillTerminate), name: NSApplication.willTerminateNotification, object: nil)
    }
    @objc private func appWillTerminate() { cancel() }
    deinit { NotificationCenter.default.removeObserver(self) }
    func start(profile: Profile, completed: @escaping (Profile) -> Void) {
        guard !running else { window?.makeKeyAndOrderFront(nil); return }
        provider = profile.provider; running = true; url = nil; code = ""
        message = "Opening \(provider.rawValue) sign-in…"
        let id = UUID(); sessionID = id
        let control = LoginProcess(); self.control = control
        let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 330), styleMask: [.titled], backing: .buffered, defer: false)
        panel.title = "Sign in to \(provider.rawValue)"
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: PortalSignInView(login: self))
        panel.center(); panel.makeKeyAndOrderFront(nil); NSApplication.shared.activate(ignoringOtherApps: true); window = panel
        task = Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try PortalClient.run(profile: profile, control: control) { address in
                        Task { @MainActor [weak self] in
                            guard let self, self.sessionID == id, self.running else { return }
                            self.url = address; self.message = "Finish signing in in your browser. This window will close when it’s complete."
                            // Open the portal ourselves; desktop helpers may not launch a browser.
                            if !NSWorkspace.shared.open(address) { self.message = "Click Open sign-in page to continue in your browser." }
                        }
                    }
                }.value
                guard sessionID == id, running else { return }
                running = false; completed(profile); window?.close(); window = nil; self.control = nil
            } catch {
                guard sessionID == id, running else { return }
                running = false; message = (error as? PortalFailure)?.localizedDescription ?? "Unable to start sign-in. Check the provider’s installation and try again."
                self.control = nil
            }
        }
    }
    func cancel() {
        sessionID = UUID(); running = false; control?.stop(); control = nil
        task?.cancel(); task = nil; url = nil; code = ""; window?.close(); window = nil
    }
    func submitCode() {
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do { try control?.submit(code.trimmingCharacters(in: .whitespacesAndNewlines)); code = "" }
        catch { message = "The sign-in session has closed. Please try again." }
    }
}
private struct PortalSignInView: View {
    @ObservedObject var login: PortalLogin
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sign in to \(login.provider.rawValue)").font(.system(size: 22, weight: .semibold))
            if login.running { ProgressView().controlSize(.small) }
            Text(login.message).font(.system(size: 13)).foregroundColor(RY.muted).fixedSize(horizontal: false, vertical: true)
            if let url = login.url { Button("Open sign-in page ↗") { NSWorkspace.shared.open(url) } }
            if login.provider == .claude && login.running {
                Text("If the browser gives you a sign-in code, paste it here.").font(.system(size: 12)).foregroundColor(RY.muted)
                HStack { SecureField("Sign-in code", text: $login.code); Button("Continue") { login.submitCode() }.disabled(login.code.isEmpty) }
            }
            Spacer()
            Button(login.running ? "Cancel sign-in" : "Close") { login.cancel() }
        }.padding(24).frame(width: 400, height: 330).foregroundColor(RY.ink).background(RY.background).tint(RY.blue)
    }
}

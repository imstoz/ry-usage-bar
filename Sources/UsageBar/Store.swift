import Foundation
import Combine
import AppKit
import UsageCore

@MainActor final class UsageStore: ObservableObject {
    let portalLogin = PortalLogin()
    @Published var profiles: [Profile] = []
    @Published var snapshots: [UUID: UsageSnapshot] = [:]
    @Published var errors: [UUID: String] = [:]
    @Published var refreshing = Set<UUID>()
    @Published var demo = false
    @Published var storageError: String?
    @Published var pinned: String? { didSet { UserDefaults.standard.set(pinned, forKey: "pinned-window") } }
    private var lastAttempt: [UUID: Date] = [:]
    private let directory: URL
    private var pollTimer: Timer?
    private var labelTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    init(storageDirectory: URL? = nil) {
        directory = storageDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("cool.ry.UsageBar")
        pinned = UserDefaults.standard.string(forKey: "pinned-window")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let config = directory.appendingPathComponent("accounts.json")
            if FileManager.default.fileExists(atPath: config.path) { profiles = try JSONDecoder().decode([Profile].self, from: Data(contentsOf: config)) }
            for profile in profiles {
                if let data = try? Data(contentsOf: cacheURL(profile.id)), let cached = try? JSONDecoder().decode(UsageSnapshot.self, from: data) { snapshots[profile.id] = cached; errors[profile.id] = "Saved reading — refresh to verify." }
            }
        } catch { storageError = "Unable to load saved accounts. Your existing files have been preserved." }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refreshAll() }
        }
        labelTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.objectWillChange.send() }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.refreshAll() }
        }
    }
    func cacheURL(_ id: UUID) -> URL { directory.appendingPathComponent("\(id).json") }
    func saveProfiles() {
        do { try JSONEncoder().encode(profiles).write(to: directory.appendingPathComponent("accounts.json"), options: .atomic) }
        catch { storageError = "Account changes could not be saved. Check folder permissions." }
    }
    func add(_ profile: Profile) {
        // A shared existing home represents one login, not two independent accounts.
        if let index = profiles.firstIndex(where: { $0.provider == profile.provider && NSString(string: $0.home).expandingTildeInPath == NSString(string: profile.home).expandingTildeInPath }) {
            let oldID = profiles[index].id
            var updated = profile; updated.id = oldID; profiles[index] = updated
            snapshots.removeValue(forKey: oldID); errors.removeValue(forKey: oldID); lastAttempt.removeValue(forKey: oldID)
            saveProfiles(); Task { await refresh(updated, force: true) }
        } else { profiles.append(profile); saveProfiles(); Task { await refresh(profile, force: true) } }
    }
    func signIn(provider: Provider, name: String, executable: String) {
        var profile = Profile(name: name, provider: provider, home: "", executable: executable)
        let folder = provider == .codex ? directory.appendingPathComponent("logins/\(profile.id.uuidString)") : FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            profile.home = folder.path
            portalLogin.start(profile: profile) { [weak self] profile in self?.add(profile) }
        } catch { storageError = "Unable to prepare the sign-in folder. Check folder permissions." }
    }
    func remove(_ profile: Profile) {
        profiles.removeAll { $0.id == profile.id }; snapshots.removeValue(forKey: profile.id); errors.removeValue(forKey: profile.id)
        if pinned?.hasPrefix(profile.id.uuidString) == true { pinned = nil }
        try? FileManager.default.removeItem(at: cacheURL(profile.id)); saveProfiles()
    }
    func refreshAll(force: Bool = false) async {
        guard !demo else { return }
        // Each account starts independently; one slow provider does not hold up the rest.
        await withTaskGroup(of: Void.self) { group in
            for profile in profiles { group.addTask { await self.refresh(profile, force: force) } }
        }
    }
    func refresh(_ profile: Profile, force: Bool) async {
        guard !demo, !refreshing.contains(profile.id) else { return }
        if let last = lastAttempt[profile.id], Date().timeIntervalSince(last) < (force ? 10 : 60) { return }
        lastAttempt[profile.id] = Date(); refreshing.insert(profile.id)
        defer { refreshing.remove(profile.id) }
        do {
            let snapshot = try await (profile.provider == .codex ? CodexClient.fetch(profile) : ClaudeClient.fetch(profile))
            guard profiles.contains(where: { $0.id == profile.id }) else { return }
            snapshots[profile.id] = snapshot; errors.removeValue(forKey: profile.id)
            do { try JSONEncoder().encode(snapshot).write(to: cacheURL(profile.id), options: .atomic) }
            catch { storageError = "Usage is available, but its cache could not be saved." }
        } catch {
            guard profiles.contains(where: { $0.id == profile.id }) else { return }
            errors[profile.id] = (error as? ConnectionError)?.localizedDescription ?? "Usage could not be read. Check your sign-in and provider version."
        }
    }
    // A pinned window wins; otherwise show the first available window.
    var menuRemaining: Double? {
        guard !demo else { return nil }
        for profile in profiles {
            guard let snapshot = snapshots[profile.id], errors[profile.id] == nil, !snapshot.isStale(at: Date()) else { continue }
            for window in snapshot.windows {
                if let pinned, "\(profile.id.uuidString)/\(window.id)" != pinned { continue }
                if let left = window.remainingPercent { return left }
            }
        }
        return nil
    }
    var menuLabel: String {
        if demo { return "Demo" }
        if let left = menuRemaining { return "\(Int(left))%" }
        return profiles.isEmpty ? "ry" : "—"
    }
    var demoProfiles: [Profile] { [Profile(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Personal", provider: .codex, home: "", executable: ""), Profile(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Studio", provider: .claude, home: "", executable: "")] }
    func demoSnapshot(_ profile: Profile) -> UsageSnapshot {
        UsageSnapshot(windows: [QuotaWindow(id: "session", label: profile.provider.rawValue, usedPercent: profile.provider == .codex ? 84 : 32, durationMinutes: 300, resetsAt: Date().addingTimeInterval(5400)), QuotaWindow(id: "weekly", label: "Weekly", usedPercent: 46, durationMinutes: 10080, resetsAt: Date().addingTimeInterval(172800))])
    }
}

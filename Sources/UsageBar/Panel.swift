import SwiftUI
import AppKit
import ServiceManagement
import UsageCore

struct UsagePanel: View {
    @ObservedObject var store: UsageStore
    @State private var adding = false
    @State private var settings = false
    var body: some View {
        VStack(spacing: 0) {
            if store.demo {
                HStack { Image(systemName: "eye"); Text("Demo · illustrative readings"); Spacer(); Button("Exit") { store.demo = false } }.font(.system(size: 11)).padding(.horizontal, 12).padding(.vertical, 10).background(RY.surface.opacity(0.45))
            }
            if adding { AccountForm(store: store, presented: $adding).padding(24) }
            else if settings { SettingsPanel(store: store, presented: $settings).padding(24) }
            else if store.profiles.isEmpty && !store.demo {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "chart.bar.xaxis").font(.system(size: 30, weight: .light)).foregroundColor(RY.indigo)
                    Text("Your limits.\nA little clearer.").font(.system(size: 28, weight: .semibold)).tracking(-1)
                    Text("Keep an eye on Codex and Claude without breaking your flow. Connect an existing login to see what’s left and when it resets.").font(.system(size: 14)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button("Connect an account") { adding = true }.buttonStyle(.borderedProminent).tint(RY.blue)
                    Button("Take a look around") { store.demo = true }.buttonStyle(.plain).foregroundColor(.secondary)
                    Text("Local by design. No analytics. No account switching.").font(.system(size: 12)).foregroundColor(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(28)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(store.demo ? store.demoProfiles : store.profiles) { profile in
                            AccountCard(profile: profile, snapshot: store.demo ? store.demoSnapshot(profile) : store.snapshots[profile.id], error: store.demo ? nil : store.errors[profile.id], busy: store.refreshing.contains(profile.id), store: store)
                        }
                    }.padding(10)
                }.frame(maxHeight: 470)
            }
            if let error = store.storageError { Text(error).font(.system(size: 12)).foregroundColor(.secondary).padding(16) }
            Divider().overlay(RY.border)
            HStack {
                Button { adding.toggle(); settings = false } label: { Label("Add account", systemImage: "plus") }.disabled(store.demo)
                Spacer()
                Button { Task { await store.refreshAll(force: true) } } label: { Image(systemName: "arrow.clockwise").frame(width: 24, height: 24) }
                    .help("Refresh usage (⌘R)").keyboardShortcut("r").disabled(store.demo || !store.refreshing.isEmpty)
                Button { settings.toggle(); adding = false } label: { Image(systemName: "slider.horizontal.3") }.help("Settings")
                Button { store.portalLogin.cancel(); NSApplication.shared.terminate(nil) } label: { Image(systemName: "power") }.help("Quit Usage Bar")
            }.font(.system(size: 12)).buttonStyle(.plain).padding(.horizontal, 12).padding(.vertical, 8)
        }.frame(width: 340).foregroundColor(.primary).background(NativePopoverMaterial()).tint(RY.blue)
            .task { await store.refreshAll() }
    }
}
struct AccountCard: View {
    let profile: Profile
    let snapshot: UsageSnapshot?
    let error: String?
    let busy: Bool
    @ObservedObject var store: UsageStore
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let stale = error != nil || (snapshot?.isStale(at: context.date) ?? true)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(profile.provider.rawValue).font(.system(size: 14, weight: .semibold))
                    Text(profile.name).font(.system(size: 12)).foregroundColor(.secondary)
                    Spacer()
                    if busy { ProgressView().controlSize(.small).accessibilityLabel("Refreshing \(profile.name)") }
                    else { Text(store.demo ? "Demo" : snapshot == nil ? "Not connected" : stale ? "Needs refresh" : "Updated").font(.system(size: 11)).foregroundColor(.secondary) }
                }
                if let snapshot {
                    ForEach(snapshot.windows) { window in
                        QuotaRow(window: window, now: context.date, stale: stale, pinned: store.pinned == "\(profile.id.uuidString)/\(window.id)") {
                            store.pinned = "\(profile.id.uuidString)/\(window.id)"
                        }.disabled(store.demo)
                    }
                    if let advice = UsageAdvice.make(snapshot: snapshot, now: context.date, failed: error != nil) {
                        VStack(alignment: .leading, spacing: 6) { HStack { Label(advice.title, systemImage: "sparkle").font(.system(size: 12, weight: .medium)); Spacer(); Image(systemName: "info.circle").foregroundColor(.secondary).help("Shown when at least 80% is used and the reading is current. Savings vary by task. Switching models may still use this quota; a lighter model may not be available on your plan.").accessibilityLabel("Advice information: savings vary by task and switching models may share this quota.") }; Text(advice.message).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(2).help(advice.message) }.padding(9).background(RY.surface.opacity(0.45)).cornerRadius(7)
                    }
                    Text("Reading from \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened))").font(.system(size: 11)).foregroundColor(.secondary)
                }
                if let error { Text(error).font(.system(size: 12)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true) }
            }.padding(10).background(RY.background.opacity(0.32)).overlay(RoundedRectangle(cornerRadius: 9).stroke(RY.border.opacity(0.55))).cornerRadius(9)
        }
    }
}
struct QuotaRow: View {
    let window: QuotaWindow
    let now: Date
    let stale: Bool
    let pinned: Bool
    let pin: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) { Text(window.durationLabel).font(.system(size: 12, weight: .medium)).help(window.label); if window.label != "Codex" && window.label != "Claude" && window.label != "Weekly" && window.label != "Session" && window.label != "codex" { Text(window.label).font(.system(size: 10)).foregroundColor(.secondary) } }
                Spacer()
                Text(window.remainingPercent.map { "\(Int($0))%" } ?? "—").font(.system(size: 20, weight: .medium)).tracking(-1).monospacedDigit()
                Text("left").font(.system(size: 12)).foregroundColor(.secondary)
                Button(action: pin) { Image(systemName: pinned ? "pin.fill" : "pin").font(.system(size: 12)).frame(width: 24, height: 24) }.buttonStyle(.plain).help("Show this window’s remaining quota in the menu bar")
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) { Capsule().fill(RY.surface); if let remaining = window.remainingPercent { Capsule().fill(stale ? RY.muted : RY.indigo).frame(width: geo.size.width * remaining / 100) } }
            }.frame(height: 4).accessibilityLabel(window.remainingPercent.map { "\(Int($0)) per cent remaining" } ?? "Usage unavailable")
            HStack {
                Text(window.usedPercent.map { "\($0.formatted(.number.precision(.fractionLength(0))))% used" } ?? "Usage unavailable")
                Spacer()
                if let reset = window.resetsAt {
                    if reset <= now { Text("Reset passed · refresh needed") }
                    else { Text("Resets \(reset, style: .relative)").help(reset.formatted(date: .complete, time: .shortened)) }
                } else { Text("Reset time unavailable") }
            }.font(.system(size: 11)).foregroundColor(.secondary)
        }
    }
}
struct AccountForm: View {
    @ObservedObject var store: UsageStore
    @Binding var presented: Bool
    @State private var provider = Provider.codex
    @State private var name = "Personal"
    @State private var existing = false
    @State private var home = "~/.codex"
    @State private var executable = AccountForm.findExecutable(.codex)
    static func findExecutable(_ provider: Provider) -> String {
        ExecutableDiscovery.find(provider)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add an account").font(.system(size: 22, weight: .semibold)).tracking(-0.6)
            Picker("Provider", selection: $provider) { ForEach(Provider.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                .onChange(of: provider) { value in home = value == .codex ? "~/.codex" : "~/.claude"; executable = Self.findExecutable(value) }
            TextField("Account name", text: $name)
            Text("Sign in on \(provider == .codex ? "ChatGPT’s" : "Claude’s") website. Usage Bar connects once you’re finished.").font(.system(size: 13)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            if provider == .claude && !existing {
                Text("This updates the Claude Code login on this Mac.").font(.system(size: 12)).foregroundColor(.secondary)
            }
            if !FileManager.default.isExecutableFile(atPath: executable) {
                Text("\(provider.rawValue == "Claude" ? "Claude Code" : "Codex") sign-in helper could not be found. Open its desktop app’s Code tab once, then try again, or choose an installed helper under Advanced.").font(.system(size: 12)).foregroundColor(.secondary)
                Link("Installation instructions ↗", destination: URL(string: provider == .codex ? "https://developers.openai.com/codex/cli" : "https://code.claude.com/docs/en/setup")!)
            }
            DisclosureGroup("Advanced") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Provider executable", text: $executable)
                    Button("Choose executable…") { let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.canChooseFiles = true; if panel.runModal() == .OK, let url = panel.url { executable = url.path } }
                    Toggle("Use an existing login", isOn: $existing)
                    if existing { TextField("CLI home folder", text: $home) }
                }.padding(.top, 8)
            }.font(.system(size: 12))
            HStack {
                Button("Cancel") { presented = false }
                Spacer()
                Button(existing ? "Connect" : "Sign in to \(provider.rawValue)") {
                    let label = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if existing { store.add(Profile(name: label, provider: provider, home: home, executable: executable)) }
                    else { store.signIn(provider: provider, name: label, executable: executable) }
                    presented = false
                }.buttonStyle(.borderedProminent).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (existing ? home.isEmpty : !FileManager.default.isExecutableFile(atPath: executable)))
            }
        }.textFieldStyle(.roundedBorder)
    }
}
struct SettingsPanel: View {
    @ObservedObject var store: UsageStore
    @Binding var presented: Bool
    @State private var launch = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Settings").font(.system(size: 22, weight: .semibold)); Spacer(); Button("Done") { presented = false } }
            Toggle("Open at login", isOn: Binding(get: { launch }, set: { enabled in
                do {
                    if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    launch = enabled; loginError = nil
                } catch {
                    loginError = "Unable to change login setting. Check System Settings → Login Items."
                    launch = SMAppService.mainApp.status == .enabled
                }
            }))
            if let loginError { Text(loginError).font(.system(size: 12)).foregroundColor(.secondary) }
            Toggle("Show demo readings", isOn: $store.demo)
            Button("Clear menu-bar pin") { store.pinned = nil }
            Divider()
            ForEach(store.profiles) { profile in
                HStack { VStack(alignment: .leading) { Text("\(profile.provider.rawValue) · \(profile.name)"); Text(profile.home).font(.system(size: 11)).foregroundColor(.secondary) }; Spacer(); Button("Remove") { store.remove(profile) } }
            }
            Text("Removing an account clears its saved reading. Your provider login stays in place.").font(.system(size: 12)).foregroundColor(.secondary)
            Divider()
            Text("ry.cool / project 01\nUsage Bar 0.1.3 · development preview").font(.system(size: 12)).foregroundColor(.secondary)
            Link("Visit ry.cool ↗", destination: URL(string: "https://ry.cool")!)
        }
    }
}

import AppKit
import SwiftUI

@main struct PreviewMain {
    @MainActor static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let directory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ry-preview-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = UsageStore(storageDirectory: directory); store.demo = true
        let dark = CommandLine.arguments.contains("--dark")
        let host = NSHostingView(rootView: UsagePanel(store: store))
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 580), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = host
        host.frame = NSRect(x: 0, y: 0, width: 340, height: 580)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw NSError(domain: "Preview", code: 1) }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { throw NSError(domain: "Preview", code: 2) }
        let path = CommandLine.arguments.dropFirst().first ?? "preview.png"
        try png.write(to: URL(fileURLWithPath: path))
        print("Saved native SwiftUI preview to \(path)")
    }
}

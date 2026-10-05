import SwiftUI
import AppKit

@main struct UsageBarApp: App {
    @StateObject private var store = UsageStore()
    var body: some Scene {
        MenuBarExtra { UsagePanel(store: store) } label: { HStack(spacing: 5) {
            Image(nsImage: MenuMeter.image(remaining: store.menuRemaining))
            Text(store.menuLabel).font(.system(size: 12, weight: .medium)).monospacedDigit()
        }.accessibilityLabel(store.menuRemaining.map { "ry Usage Bar, \(Int($0)) per cent remaining" } ?? "ry Usage Bar, usage unavailable")
            .help("ry Usage Bar · percentage remaining") }
            .menuBarExtraStyle(.window)
    }
}

// Template artwork follows the menu bar’s light/dark contrast automatically.
private enum MenuMeter {
    static func image(remaining: Double?) -> NSImage {
        let image = NSImage(size: NSSize(width: 22, height: 14))
        image.lockFocus()
        for index in 0..<4 {
            let rect = NSRect(x: CGFloat(index) * 5.5, y: 2, width: 4, height: 10)
            NSColor.black.withAlphaComponent(0.25).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 1, yRadius: 1).fill()
            if let remaining {
                let fraction = min(1, max(0, remaining / 25 - Double(index)))
                if fraction > 0 {
                    NSColor.black.setFill()
                    NSBezierPath(roundedRect: NSRect(x: rect.minX, y: rect.minY, width: rect.width * fraction, height: rect.height), xRadius: 0.5, yRadius: 0.5).fill()
                }
            }
        }
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}

import SwiftUI

enum RY {
    static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255, alpha: 1)
        })
    }
    static let background = adaptive(0xffffff, 0x111113)
    static let surface = adaptive(0xf5f5f7, 0x1c1c1e)
    static let ink = adaptive(0x1d1d1f, 0xf5f5f7)
    static let muted = adaptive(0x6e6e73, 0xa1a1a6)
    static let border = adaptive(0xe5e5ea, 0x333336)
    static let blue = Color(red: 0, green: 111.0/255, blue: 230.0/255)
    static let indigo = Color(red: 88.0/255, green: 86.0/255, blue: 214.0/255)
}

// Use the same system material as native macOS popovers. macOS adapts this
// to appearance, wallpaper and the user's Reduce Transparency preference.
struct NativePopoverMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

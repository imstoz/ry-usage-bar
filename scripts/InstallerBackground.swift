import AppKit
import Foundation
let image = NSImage(size: NSSize(width: 640, height: 400))
image.lockFocus()
NSColor(srgbRed: 0.97, green: 0.97, blue: 0.985, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: 640, height: 400).fill()
func text(_ value: String, y: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular, colour: NSColor = .secondaryLabelColor) {
 let a: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: colour]
 let s = NSAttributedString(string: value, attributes: a)
 s.draw(at: NSPoint(x: (640 - s.size().width) / 2, y: y))
}
text("ry Usage Bar", y: 325, size: 25, weight: .semibold, colour: NSColor(srgbRed: 0.114, green: 0.114, blue: 0.122, alpha: 1))
text("Drag the app into Applications", y: 295, size: 14)
text("→", y: 183, size: 40, colour: NSColor(srgbRed: 0.345, green: 0.337, blue: 0.839, alpha: 1))
text("Then open it from Applications and look in the menu bar.", y: 69, size: 12)
text("A little more headroom.", y: 40, size: 10)
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))

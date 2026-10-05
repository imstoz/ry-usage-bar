import AppKit
import Foundation
let output = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
NSColor(srgbRed: 0.96, green: 0.96, blue: 0.97, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 48, y: 48, width: 928, height: 928), xRadius: 205, yRadius: 205).fill()
let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 410, weight: .semibold), .foregroundColor: NSColor(srgbRed: 0.114, green: 0.114, blue: 0.122, alpha: 1), .kern: -24]
let word = NSAttributedString(string: "ry", attributes: attributes)
word.draw(at: NSPoint(x: (1024 - word.size().width) / 2, y: 280))
NSColor(srgbRed: 0.345, green: 0.337, blue: 0.839, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 278, y: 237, width: 468, height: 28), xRadius: 14, yRadius: 14).fill()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))

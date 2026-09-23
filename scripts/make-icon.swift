// Renders Resources/AppIcon.icns. Run: swift scripts/make-icon.swift
import AppKit

func render(_ size: CGFloat) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = size / 1024
    let rect = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let path = NSBezierPath(roundedRect: rect, xRadius: 185 * s, yRadius: 185 * s)
    let shadow = NSShadow()
    shadow.shadowBlurRadius = 24 * s
    shadow.shadowOffset = NSSize(width: 0, height: -10 * s)
    shadow.shadowColor = .black.withAlphaComponent(0.3)
    shadow.set()
    NSGradient(colors: [NSColor(red: 0.99, green: 0.98, blue: 0.95, alpha: 1), NSColor(red: 0.92, green: 0.90, blue: 0.86, alpha: 1)])!.draw(in: path, angle: -90)
    NSShadow().set()
    // Lines of "text"
    NSColor(white: 0.2, alpha: 0.18).setFill()
    for (i, w) in [520.0, 600, 440, 560].enumerated() {
        NSBezierPath(roundedRect: NSRect(x: 212 * s, y: (300 - Double(i) * 58) * s, width: w * s, height: 22 * s), xRadius: 11 * s, yRadius: 11 * s).fill()
    }
    // "M↓" glyph
    let accent = NSColor(red: 0.20, green: 0.45, blue: 0.95, alpha: 1)
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 330 * s, weight: .heavy), .foregroundColor: NSColor(white: 0.13, alpha: 1)]
    let m = NSAttributedString(string: "M", attributes: attrs)
    m.draw(at: NSPoint(x: 205 * s, y: 390 * s))
    let arrow = NSAttributedString(string: "↓", attributes: [.font: NSFont.systemFont(ofSize: 300 * s, weight: .heavy), .foregroundColor: accent])
    arrow.draw(at: NSPoint(x: 540 * s, y: 400 * s))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: "Resources/AppIcon.iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(CGFloat(base)).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(CGFloat(base * 2)).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try! p.run(); p.waitUntilExit()
try? fm.removeItem(at: iconset)
print("Wrote Resources/AppIcon.icns")

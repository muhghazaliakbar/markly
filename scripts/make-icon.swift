// Renders Resources/AppIcon.icns.
//   swift scripts/make-icon.swift            → writes the icon set
//   swift scripts/make-icon.swift preview    → also writes previews to $TMPDIR at several sizes
//
// Design: the Markdown mark (a frame holding "M↓") redrawn in the macOS 26 icon style — a true superellipse
// squircle with a deep blue→indigo gradient and soft light, and a white glyph built from rounded strokes so it
// stays crisp down to 16 px.
import AppKit

// MARK: Geometry

/// Apple-style squircle: a superellipse (n ≈ 5) rather than a rounded rectangle, so the curvature is continuous.
func squircle(in rect: CGRect, exponent n: CGFloat = 5) -> CGPath {
    let path = CGMutablePath()
    let a = rect.width / 2, b = rect.height / 2, cx = rect.midX, cy = rect.midY
    let steps = 720
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = cx + a * copysign(pow(abs(c), 2 / n), c)
        let y = cy + b * copysign(pow(abs(s), 2 / n), s)
        i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
    }
    path.closeSubpath()
    return path
}

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

/// The M↓ glyph as stroked paths, centred in `rect`.
func markGlyph(in rect: CGRect, stroke w: CGFloat) -> CGPath {
    let path = CGMutablePath()
    // M: two posts joined by a V that dips to 55% of the height.
    let mW = rect.width * 0.54, h = rect.height
    let x0 = rect.minX, y0 = rect.minY
    path.move(to: CGPoint(x: x0, y: y0))
    path.addLine(to: CGPoint(x: x0, y: y0 + h))
    path.addLine(to: CGPoint(x: x0 + mW / 2, y: y0 + h * 0.45))
    path.addLine(to: CGPoint(x: x0 + mW, y: y0 + h))
    path.addLine(to: CGPoint(x: x0 + mW, y: y0))
    // ↓: shaft plus chevron.
    let ax = rect.maxX - rect.width * 0.14
    path.move(to: CGPoint(x: ax, y: y0 + h))
    path.addLine(to: CGPoint(x: ax, y: y0 + w * 0.2))
    let arm = rect.width * 0.16
    path.move(to: CGPoint(x: ax - arm, y: y0 + arm + w * 0.2))
    path.addLine(to: CGPoint(x: ax, y: y0 + w * 0.2))
    path.addLine(to: CGPoint(x: ax + arm, y: y0 + arm + w * 0.2))
    return path.copy(strokingWithWidth: w, lineCap: .round, lineJoin: .round, miterLimit: 10)
}

// MARK: Drawing

func render(size: Int) -> CGImage {
    let s = CGFloat(size) / 1024
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: s, y: s)
    ctx.interpolationQuality = .high

    // macOS icon grid: 824 pt body centred in 1024, with room for the drop shadow.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = squircle(in: body)

    // Drop shadow under the whole tile.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.28))
    ctx.addPath(shape); ctx.setFillColor(color(0x2B3FD9)); ctx.fillPath()
    ctx.restoreGState()

    // Background: deep blue → indigo, lit from the top left.
    ctx.saveGState()
    ctx.addPath(shape); ctx.clip()
    let bg = CGGradient(colorsSpace: nil, colors: [color(0x4F8BFF), color(0x3457F2), color(0x3A2DBE)] as CFArray,
                        locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    let glow = CGGradient(colorsSpace: nil, colors: [color(0xFFFFFF, 0.32), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 300, y: 860), startRadius: 0,
                           endCenter: CGPoint(x: 300, y: 860), endRadius: 620, options: [])
    // Glass rim: a thin bright edge along the top, fading down.
    ctx.addPath(shape)
    ctx.setLineWidth(6)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    let rim = CGGradient(colorsSpace: nil, colors: [color(0xFFFFFF, 0.55), color(0xFFFFFF, 0.05)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(rim, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 500), options: [])
    ctx.restoreGState()

    // Small sizes (16/32 px, Finder sidebar and menus) drop the frame and enlarge the glyph, as Apple's own
    // icons do, so M↓ stays readable instead of blurring into the frame.
    if size <= 64 {
        let glyph = markGlyph(in: CGRect(x: 250, y: 368, width: 524, height: 288), stroke: 104)
        drawGlass(ctx, paths: [glyph])
        return ctx.makeImage()!
    }

    // The Markdown mark: a rounded frame around M↓.
    let frame = CGRect(x: 212, y: 332, width: 600, height: 360)
    let framePath = CGPath(roundedRect: frame, cornerWidth: 86, cornerHeight: 86, transform: nil)
        .copy(strokingWithWidth: 40, lineCap: .round, lineJoin: .round, miterLimit: 10)
    let glyph = markGlyph(in: CGRect(x: 302, y: 418, width: 420, height: 188), stroke: 54)
    drawGlass(ctx, paths: [framePath, glyph])
    return ctx.makeImage()!
}

/// White glass: soft shadow, top-lit gradient fill, and a fine highlight on the upper edge.
func drawGlass(_ ctx: CGContext, paths: [CGPath]) {
    let combined = CGMutablePath()
    paths.forEach { combined.addPath($0) }
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0x10124A, 0.35))
    ctx.addPath(combined); ctx.setFillColor(color(0xFFFFFF)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(combined); ctx.clip()
    let fill = CGGradient(colorsSpace: nil, colors: [color(0xFFFFFF), color(0xDCE4FF)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(fill, start: CGPoint(x: 512, y: 700), end: CGPoint(x: 512, y: 320), options: [])
    ctx.restoreGState()
}

func png(_ image: CGImage) -> Data {
    NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
}

// MARK: Output

let fm = FileManager.default
let args = CommandLine.arguments
if args.contains("preview") {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
    for size in [1024, 128, 32, 16] {
        try! png(render(size: size)).write(to: tmp.appendingPathComponent("icon-\(size).png"))
    }
    print("Previews in \(tmp.path)")
}

let iconset = URL(fileURLWithPath: "Resources/AppIcon.iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! png(render(size: base)).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! png(render(size: base * 2)).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try! p.run(); p.waitUntilExit()
try? fm.removeItem(at: iconset)
print("Wrote Resources/AppIcon.icns")

// Renders Resources/AppIcon.icns.
//   swift scripts/make-icon.swift            → writes the icon set
//   swift scripts/make-icon.swift preview    → also writes previews to $TMPDIR at several sizes
//
// Design: a tilted white page with a folded corner, carrying Markdown's heading mark "#", on a warm
// coral→pink superellipse tile in the macOS 26 style. At 16 and 32 px the page is dropped and a bold white "#"
// sits directly on the tile so it stays readable in the Finder sidebar and menus.
import AppKit

// MARK: Geometry

/// Apple-style squircle: a superellipse (n ≈ 5) rather than a rounded rectangle, so the curvature is continuous.
func squircle(in rect: CGRect, exponent n: CGFloat = 5) -> CGPath {
    let path = CGMutablePath()
    let a = rect.width / 2, b = rect.height / 2, cx = rect.midX, cy = rect.midY
    for i in 0...720 {
        let t = CGFloat(i) / 720 * 2 * .pi
        let c = cos(t), s = sin(t)
        let p = CGPoint(x: cx + a * copysign(pow(abs(c), 2 / n), c), y: cy + b * copysign(pow(abs(s), 2 / n), s))
        i == 0 ? path.move(to: p) : path.addLine(to: p)
    }
    path.closeSubpath()
    return path
}

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

func gradient(_ colors: [(UInt32, CGFloat)], _ locations: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors.map { color($0.0, $0.1) } as CFArray,
               locations: locations)!
}

/// A page with smooth corners and its top-right corner folded down by `fold`.
func pagePath(_ r: CGRect, radius: CGFloat, fold: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let k: CGFloat = 0.62  // control-point factor for a softer, near-continuous corner
    p.move(to: CGPoint(x: r.minX + radius, y: r.minY))
    p.addLine(to: CGPoint(x: r.maxX - radius, y: r.minY))
    p.addCurve(to: CGPoint(x: r.maxX, y: r.minY + radius),
               control1: CGPoint(x: r.maxX - radius * (1 - k), y: r.minY), control2: CGPoint(x: r.maxX, y: r.minY + radius * (1 - k)))
    p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - fold))
    p.addLine(to: CGPoint(x: r.maxX - fold, y: r.maxY))
    p.addLine(to: CGPoint(x: r.minX + radius, y: r.maxY))
    p.addCurve(to: CGPoint(x: r.minX, y: r.maxY - radius),
               control1: CGPoint(x: r.minX + radius * (1 - k), y: r.maxY), control2: CGPoint(x: r.minX, y: r.maxY - radius * (1 - k)))
    p.addLine(to: CGPoint(x: r.minX, y: r.minY + radius))
    p.addCurve(to: CGPoint(x: r.minX + radius, y: r.minY),
               control1: CGPoint(x: r.minX, y: r.minY + radius * (1 - k)), control2: CGPoint(x: r.minX + radius * (1 - k), y: r.minY))
    p.closeSubpath()
    return p
}

/// "#" from four rounded bars; the verticals lean like a typeset hash.
func hashPath(center c: CGPoint, length: CGFloat, gap: CGFloat, slant: CGFloat, weight: CGFloat) -> CGPath {
    let p = CGMutablePath()
    for dx in [-gap, gap] {
        p.move(to: CGPoint(x: c.x + dx - slant, y: c.y - length / 2))
        p.addLine(to: CGPoint(x: c.x + dx + slant, y: c.y + length / 2))
    }
    for dy in [-gap, gap] {
        p.move(to: CGPoint(x: c.x - length / 2, y: c.y + dy))
        p.addLine(to: CGPoint(x: c.x + length / 2, y: c.y + dy))
    }
    return p.copy(strokingWithWidth: weight, lineCap: .round, lineJoin: .round, miterLimit: 1)
}

func fill(_ ctx: CGContext, _ path: CGPath, _ g: CGGradient, from: CGPoint, to: CGPoint) {
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}

func shadowed(_ ctx: CGContext, _ path: CGPath, offset: CGFloat, blur: CGFloat, _ shadow: CGColor) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -offset), blur: blur, color: shadow)
    ctx.addPath(path); ctx.setFillColor(color(0xFFFFFF)); ctx.fillPath()
    ctx.restoreGState()
}

// MARK: Drawing

let coral = gradient([(0xFFA15E, 1), (0xFF6A6A, 1), (0xE9357E, 1)], [0, 0.5, 1])
let ink = gradient([(0xFF9148, 1), (0xF2366F, 1)])

func render(size: Int) -> CGImage {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    ctx.interpolationQuality = .high

    // Tile on the macOS icon grid: 824 pt body centred in 1024, with room for the drop shadow.
    let tile = squircle(in: CGRect(x: 100, y: 100, width: 824, height: 824))
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x4A0A20, 0.30))
    ctx.addPath(tile); ctx.setFillColor(color(0xE9357E)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(tile); ctx.clip()
    ctx.drawLinearGradient(coral, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    let glow = gradient([(0xFFFFFF, 0.30), (0xFFFFFF, 0)], [0, 1])
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 280, y: 880), startRadius: 0,
                           endCenter: CGPoint(x: 280, y: 880), endRadius: 660, options: [])
    ctx.addPath(tile); ctx.setLineWidth(6); ctx.replacePathWithStrokedPath(); ctx.clip()
    ctx.drawLinearGradient(gradient([(0xFFFFFF, 0.6), (0xFFFFFF, 0)], [0, 1]),
                           start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 520), options: [])
    ctx.restoreGState()

    // Small sizes: a bold white "#" straight on the tile.
    if size <= 64 {
        let mark = hashPath(center: CGPoint(x: 512, y: 512), length: 470, gap: 108, slant: 50, weight: 110)
        shadowed(ctx, mark, offset: 8, blur: 18, color(0x7A1030, 0.35))
        fill(ctx, mark, gradient([(0xFFFFFF, 1), (0xFFE7EA, 1)]), from: CGPoint(x: 512, y: 760), to: CGPoint(x: 512, y: 270))
        return ctx.makeImage()!
    }

    // The page, tilted slightly.
    ctx.saveGState()
    ctx.translateBy(x: 512, y: 512); ctx.rotate(by: -0.105); ctx.translateBy(x: -512, y: -512)
    let rect = CGRect(x: 257, y: 206, width: 510, height: 612)
    let fold: CGFloat = 138
    let page = pagePath(rect, radius: 54, fold: fold)
    shadowed(ctx, page, offset: 20, blur: 44, color(0x7A1030, 0.36))
    fill(ctx, page, gradient([(0xFFFFFF, 1), (0xFFF4F2, 1)]), from: CGPoint(x: 512, y: rect.maxY), to: CGPoint(x: 512, y: rect.minY))

    // Folded corner: the flap, with its own soft shadow cast onto the page.
    let corner = CGPoint(x: rect.maxX - fold, y: rect.maxY - fold)
    let flap = CGMutablePath()
    flap.move(to: CGPoint(x: rect.maxX, y: rect.maxY - fold))
    flap.addQuadCurve(to: CGPoint(x: corner.x + 26, y: corner.y + 26), control: CGPoint(x: corner.x + 70, y: corner.y + 8))
    flap.addQuadCurve(to: CGPoint(x: rect.maxX - fold, y: rect.maxY), control: CGPoint(x: corner.x + 8, y: corner.y + 70))
    flap.closeSubpath()
    ctx.saveGState()
    ctx.addPath(page); ctx.clip()
    ctx.setShadow(offset: CGSize(width: -6, height: -10), blur: 22, color: color(0x7A1030, 0.30))
    ctx.addPath(flap); ctx.setFillColor(color(0xFFE0DA)); ctx.fillPath()
    ctx.restoreGState()
    fill(ctx, flap, gradient([(0xFFE9E4, 1), (0xF8B7B1, 1)]), from: CGPoint(x: rect.maxX - 20, y: rect.maxY - 20), to: corner)

    // "#", nudged away from the fold so it sits in the optical centre of the page.
    let mark = hashPath(center: CGPoint(x: 500, y: 500), length: 318, gap: 74, slant: 36, weight: 60)
    fill(ctx, mark, ink, from: CGPoint(x: 360, y: 660), to: CGPoint(x: 650, y: 340))
    ctx.restoreGState()
    return ctx.makeImage()!
}

func png(_ image: CGImage) -> Data {
    NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
}

// MARK: Output

let fm = FileManager.default
if CommandLine.arguments.contains("preview") {
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
    for size in [1024, 128, 64, 32, 16] {
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

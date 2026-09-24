import AppKit
import SwiftUI

/// Markly's own colours, the same ones as the website: a coral → rose gradient, rose ink for accents,
/// warm paper and a warm near-black for text.
enum Brand {
    static let coral = rgb(0xf4623a)
    static let rose = rgb(0xe9357e)
    static let berry = rgb(0xc9246a)

    /// The accent: deep rose on paper, a lighter rose on dark so links keep their contrast.
    static let accent = Palette.dynamic(light: rgb(0xd92d63), dark: rgb(0xff5c8d))

    /// Selected pills, the current tick and prominent swatches.
    static var gradient: LinearGradient {
        LinearGradient(stops: [.init(color: Color(nsColor: coral), location: 0),
                               .init(color: Color(nsColor: rose), location: 0.55),
                               .init(color: Color(nsColor: berry), location: 1)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func rgb(_ v: UInt32, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255,
                blue: CGFloat(v & 0xff) / 255, alpha: alpha)
    }
}

/// The colours of the page: paper, ink and the quiet marks around it. The Markly accent brings the warm
/// palette; every other accent keeps the neutral system colours.
struct Theme {
    var paper: NSColor
    var text: NSColor
    var secondary: NSColor
    /// Markdown markers (`#`, `**`, `[]()`), fences and table pipes.
    var syntax: NSColor
    /// Text outside the focused paragraph.
    var dim: NSColor
    var codeBackground: NSColor
    var rule: NSColor
    var mark: NSColor
    /// A wash laid over the sidebar's behind-window blur, if any.
    var sidebarWash: [Color]?

    var warm: Bool { sidebarWash != nil }

    static let system = Theme(
        paper: .textBackgroundColor,
        text: .labelColor,
        secondary: .secondaryLabelColor,
        syntax: .tertiaryLabelColor,
        dim: .tertiaryLabelColor,
        codeBackground: Palette.dynamic(light: NSColor(white: 0, alpha: 0.045), dark: NSColor(white: 1, alpha: 0.07)),
        rule: .separatorColor,
        mark: Palette.accentTint(.systemYellow, alpha: 0.35),
        sidebarWash: nil)

    static let markly: Theme = {
        let d = Palette.dynamic
        let rgb = Brand.rgb
        return Theme(
            paper: d(rgb(0xfffbfa, 1), rgb(0x1e1719, 1)),
            text: d(rgb(0x24171b, 1), rgb(0xf4e8eb, 1)),
            secondary: d(rgb(0x6f5c61, 1), rgb(0xbba5ab, 1)),
            syntax: d(rgb(0xc2a9af, 1), rgb(0x7a6368, 1)),
            dim: d(rgb(0xc2a9af, 1), rgb(0x6c575c, 1)),
            codeBackground: d(rgb(0x4a0a20, 0.055), rgb(0xffd6e2, 0.07)),
            rule: d(rgb(0x4a0a20, 0.12), rgb(0xffd6e2, 0.12)),
            mark: d(rgb(0xffa15e, 0.34), rgb(0xffa15e, 0.3)),
            sidebarWash: [Color(nsColor: d(rgb(0xfdf0ec, 0.55), rgb(0x46242c, 0.26))),
                          Color(nsColor: d(rgb(0xfaecf0, 0.55), rgb(0x3c1e2a, 0.26)))])
    }()

    /// Extra preview CSS for the warm palette, layered over the page's own variables.
    static let marklyCSS = """
    :root { --accent: #d92d63; --fg: #24171b; --muted: #6f5c61; --border: rgba(74,10,32,.1); --code: rgba(74,10,32,.055); --bg: #fffbfa; --quote: rgba(242,54,111,.35); --mark: rgba(255,161,94,.34); }
    @media (prefers-color-scheme: dark) { :root { --accent: #ff5c8d; --fg: #f4e8eb; --muted: #bba5ab; --border: rgba(255,214,226,.12); --code: rgba(255,214,226,.07); --bg: #1e1719; --quote: rgba(255,92,141,.45); --mark: rgba(255,161,94,.3); } }
    h1, h2, h3 { letter-spacing: -0.015em; }
    h1, h2 { padding-bottom: .3em; border-bottom: 1px solid var(--border); }
    blockquote { border-left-color: var(--quote); }
    mark { background: var(--mark); }
    ::selection { background: rgba(242,54,111,.2); }
    @media print { :root { --bg: #fff; } }
    """
}

extension AccentChoice {
    var theme: Theme { self == .markly ? .markly : .system }

    /// How selected controls are filled: the brand gradient for Markly, the accent's own gradient otherwise.
    var fill: AnyShapeStyle {
        self == .markly ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(color.gradient)
    }
}

extension EnvironmentValues {
    /// Fill for selected pills and ticks in glass controls; nil falls back to the control's accent gradient.
    @Entry var accentFill: AnyShapeStyle? = nil
}

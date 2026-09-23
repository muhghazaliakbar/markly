import AppKit
import SwiftUI

enum FontChoice: String, CaseIterable, Identifiable {
    case sans, serif, mono
    var id: Self { self }
    var label: String {
        switch self {
        case .sans: "Sans Serif"
        case .serif: "Serif"
        case .mono: "Monospace"
        }
    }

    var design: Font.Design {
        switch self {
        case .sans: .default
        case .serif: .serif
        case .mono: .monospaced
        }
    }

    func font(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        switch self {
        case .sans:
            return .systemFont(ofSize: size, weight: weight)
        case .serif:
            let base = NSFont.systemFont(ofSize: size, weight: weight)
            if let d = base.fontDescriptor.withDesign(.serif), let f = NSFont(descriptor: d, size: size) {
                return f
            }
            return NSFont(name: "Georgia", size: size) ?? base
        case .mono:
            return .monospacedSystemFont(ofSize: size, weight: weight)
        }
    }
}

enum SyntaxVisibility: String, CaseIterable, Identifiable {
    case always, focused, hidden
    var id: Self { self }
    var label: String {
        switch self {
        case .always: "Show"
        case .focused: "Auto"
        case .hidden: "Hide"
        }
    }
    var icon: String {
        switch self {
        case .always: "eye"
        case .focused: "character.cursor.ibeam"
        case .hidden: "eye.slash"
        }
    }
    var help: String {
        switch self {
        case .always: "Always show Markdown syntax"
        case .focused: "Show syntax only on the line you're editing"
        case .hidden: "Never show Markdown syntax"
        }
    }
}

enum ImagePreview: String, CaseIterable, Identifiable {
    case off, small, medium, large
    var id: Self { self }
    var label: String { self == .off ? "Off" : rawValue.capitalized }
    /// Fraction of the text column an image may occupy.
    var fraction: CGFloat {
        switch self {
        case .off: 0
        case .small: 0.4
        case .medium: 0.7
        case .large: 1
        }
    }
}

enum TextSize: Double, CaseIterable, Identifiable {
    case small = 14, medium = 16, large = 18, huge = 21
    var id: Self { self }
    var label: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .huge: "Extra Large"
        }
    }
    static func nearest(_ v: Double) -> TextSize {
        allCases.min { abs($0.rawValue - v) < abs($1.rawValue - v) } ?? .medium
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case light, dark, system
    var id: Self { self }
    var label: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .light: "sun.max"
        case .dark: "moon"
        case .system: "circle.lefthalf.filled"
        }
    }

    /// Switches the app appearance with a short cross-fade of every window, like System Settings does.
    func apply(animated: Bool = true) {
        if animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            for window in NSApp.windows where window.isVisible {
                guard let frameView = window.contentView?.superview else { continue }
                frameView.wantsLayer = true
                let fade = CATransition()
                fade.type = .fade
                fade.duration = 0.28
                fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                frameView.layer?.add(fade, forKey: "themeFade")
            }
        }
        switch self {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

enum AccentChoice: String, CaseIterable, Identifiable {
    case system, blue, purple, pink, red, orange, yellow, green, graphite, custom
    var id: Self { self }
    var label: String {
        switch self {
        case .system: "macOS Accent"
        case .custom: "Custom"
        default: rawValue.capitalized
        }
    }

    /// The fixed presets shown as swatches (custom has its own color well).
    static var presets: [AccentChoice] { allCases.filter { $0 != .custom } }

    var nsColor: NSColor {
        switch self {
        case .custom: NSColor(hex: UserDefaults.standard.string(forKey: Pref.accentCustom) ?? "") ?? .controlAccentColor
        case .system: .controlAccentColor
        case .blue: .systemBlue
        case .purple: .systemPurple
        case .pink: .systemPink
        case .red: .systemRed
        case .orange: .systemOrange
        case .yellow: .systemYellow
        case .green: .systemGreen
        case .graphite: .systemGray
        }
    }

    var color: Color { Color(nsColor: nsColor) }
}

extension CaseIterable where Self: Equatable, AllCases: BidirectionalCollection, AllCases.Index == Int {
    var next: Self {
        let all = Self.allCases
        let i = all.firstIndex(of: self) ?? 0
        return all[(i + 1) % all.count]
    }
    var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

/// Keys for `@AppStorage`, kept in one place.
enum Pref {
    static let font = "font"
    static let fontSize = "fontSize"
    static let lineSpacing = "lineSpacing"
    static let editorWidth = "editorWidth"
    static let syntax = "syntaxVisibility"
    static let theme = "theme"
    static let accent = "accent"
    static let spellCheck = "spellCheck"
    static let showStatusBar = "showStatusBar"
    static let imagePreview = "imagePreview"
    static let accentCustom = "accentCustom"
    // Editor behavior
    static let typewriter = "typewriterScrolling"
    static let focusParagraph = "focusParagraph"
    static let smartLists = "smartLists"
    static let animateTransitions = "animateTransitions"
    static let reopenLastNote = "reopenLastNote"
    static let newNoteExtension = "newNoteExtension"
    static let selectionToolbar = "selectionToolbar"
    static let syncPreview = "syncPreview"
    // Privacy
    static let previewNetwork = "previewNetwork"
    static let remoteImages = "remoteImages"

    /// Every key above, for "Reset All Settings". Folders in the sidebar are not settings and are kept.
    static let all = [font, fontSize, lineSpacing, editorWidth, syntax, theme, accent, spellCheck, showStatusBar,
                      imagePreview, accentCustom, typewriter, focusParagraph, smartLists, animateTransitions,
                      reopenLastNote, newNoteExtension, selectionToolbar, syncPreview, previewNetwork, remoteImages, "showPreview", "showInspector"]

    static func bool(_ key: String, default value: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? value
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255,
                  blue: CGFloat(v & 0xff) / 255, alpha: 1)
    }
}

/// Everything the text view needs to know to style the document.
struct EditorStyle: Equatable {
    var font: FontChoice = .sans
    var fontSize: CGFloat = 16
    var lineSpacing: CGFloat = 1.4
    var maxWidth: CGFloat = 720
    var syntax: SyntaxVisibility = .focused
    var accent: AccentChoice = .system
    var spellCheck: Bool = true
    var imagePreview: ImagePreview = .medium
    /// Changes when a custom accent is picked, so the editor restyles.
    var accentHex: String = ""
    var typewriter: Bool = false
    var focusParagraph: Bool = false
    var smartLists: Bool = true
    var selectionToolbar: Bool = true
}

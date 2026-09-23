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
    case focused, always
    var id: Self { self }
    var label: String {
        switch self {
        case .focused: "Hide except on current line"
        case .always: "Always show"
        }
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: Self { self }
    var label: String { rawValue.capitalized }

    func apply() {
        switch self {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

enum AccentChoice: String, CaseIterable, Identifiable {
    case system, blue, purple, pink, red, orange, yellow, green, graphite
    var id: Self { self }
    var label: String { self == .system ? "macOS Accent" : rawValue.capitalized }

    var nsColor: NSColor {
        switch self {
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
}

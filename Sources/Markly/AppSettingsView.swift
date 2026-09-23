import SwiftUI

/// The standard macOS Settings window (⌘,) for app-wide preferences. Per-writing settings live in the
/// editor panel instead.
struct AppSettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") { GeneralSettings() }
            Tab("Shortcuts", systemImage: "command") { ShortcutsSettings() }
        }
        .scenePadding()
        .frame(width: 560)
    }
}

private struct GeneralSettings: View {
    @AppStorage(Pref.theme) private var theme = AppTheme.system
    @AppStorage(Pref.accent) private var accent = AccentChoice.system
    @AppStorage(Pref.showStatusBar) private var showStatusBar = true

    var body: some View {
        Form {
            Section {
                LabeledContent("Appearance") {
                    HStack(spacing: 16) {
                        ForEach(AppTheme.allCases) { option in
                            AppearanceThumbnail(theme: option, selected: theme == option, accent: accent.color) {
                                withAnimation(GlassStyle.snappy) { theme = option }
                            }
                        }
                    }
                }
                LabeledContent("Accent color") {
                    HStack(spacing: 10) {
                        ForEach(AccentChoice.allCases) { choice in
                            AccentSwatch(choice: choice, selected: accent == choice) {
                                withAnimation(GlassStyle.snappy) { accent = choice }
                            }
                        }
                    }
                }
            }
            Section {
                Toggle("Show word count", isOn: $showStatusBar)
            } footer: {
                Text("Font, spacing, width and syntax display are set per writing session in the editor panel (⌥⌘I).")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onChange(of: theme) { _, t in t.apply() }
    }
}

/// A miniature window in the style of System Settings › Appearance.
private struct AppearanceThumbnail: View {
    var theme: AppTheme
    var selected: Bool
    var accent: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    switch theme {
                    case .light: window(light: true)
                    case .dark: window(light: false)
                    case .system:
                        window(light: true)
                            .overlay(alignment: .trailing) {
                                window(light: false).mask(alignment: .trailing) {
                                    Rectangle().frame(width: 36)
                                }
                            }
                    }
                }
                .frame(width: 72, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(selected ? accent : Color.primary.opacity(0.12), lineWidth: selected ? 2.5 : 1)
                }
                .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                Text(theme == .system ? "Auto" : theme.label)
                    .font(.caption)
                    .foregroundStyle(selected ? .primary : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func window(light: Bool) -> some View {
        let bg = light ? Color(white: 0.96) : Color(white: 0.16)
        let bar = light ? Color(white: 0.86) : Color(white: 0.28)
        let line = light ? Color(white: 0.78) : Color(white: 0.36)
        return ZStack(alignment: .topLeading) {
            bg
            HStack(spacing: 0) {
                bar.frame(width: 18)
                VStack(alignment: .leading, spacing: 4) {
                    Capsule().fill(line).frame(width: 30, height: 4)
                    Capsule().fill(line).frame(width: 38, height: 3)
                    Capsule().fill(accent.opacity(0.9)).frame(width: 22, height: 3)
                }
                .padding(8)
            }
        }
    }
}

private struct AccentSwatch: View {
    var choice: AccentChoice
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(choice == .system
                      ? AnyShapeStyle(AngularGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .red], center: .center))
                      : AnyShapeStyle(choice.color.gradient))
                .frame(width: 18, height: 18)
                .overlay {
                    if selected { Circle().fill(.white).frame(width: 7, height: 7).transition(.scale) }
                }
                .overlay { Circle().strokeBorder(.black.opacity(0.1), lineWidth: 0.5) }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(choice.label)
        .accessibilityLabel(choice.label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct ShortcutsSettings: View {
    private let groups: [(String, [(String, String)])] = [
        ("Formatting", [("Bold", "⌘B"), ("Italic", "⌘I"), ("Strikethrough", "⇧⌘X"), ("Highlight", "⇧⌘H"),
                        ("Inline code", "⌘E"), ("Link", "⌘K"), ("Code block", "⌥⌘C"), ("Table", "⌥⌘T")]),
        ("Blocks", [("Heading 1–4", "⌥⌘1–4"), ("Body text", "⌥⌘0"), ("Bulleted list", "⇧⌘8"),
                    ("Numbered list", "⇧⌘7"), ("Task list", "⇧⌘T"), ("Quote", "⌘'"), ("Indent / outdent", "⇥ / ⇧⇥")]),
        ("Navigation", [("Open note 1–9", "⌘1–9"), ("Add folder", "⌘O"), ("New file", "⌘N"), ("Find", "⌘F"),
                        ("Filter notes", "⇧⌘L"), ("Preview", "⌥⌘P"), ("Focus mode", "⇧⌘F"), ("Text size", "⌘+ / ⌘−")]),
        ("Windows", [("Editor settings", "⌥⌘I"), ("App settings", "⌘,")]),
    ]

    var body: some View {
        Form {
            ForEach(groups, id: \.0) { group in
                Section(group.0) {
                    ForEach(group.1, id: \.0) { item in
                        LabeledContent(item.0) {
                            Text(item.1)
                                .font(.system(.body, design: .rounded).weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: 460)
    }
}

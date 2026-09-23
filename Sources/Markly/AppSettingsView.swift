import SwiftUI

/// The standard macOS Settings window (⌘,) for app-wide preferences. Settings that shape the page while
/// writing (font, spacing, width, syntax) live in the editor panel instead (⌥⌘I).
struct AppSettingsView: View {
    /// Reopens on the tab you last used, like Apple's own Settings windows.
    @AppStorage("settingsTab") private var tab = "general"

    var body: some View {
        TabView(selection: $tab) {
            Tab("General", systemImage: "gearshape", value: "general") { GeneralSettings() }
            Tab("Editor", systemImage: "character.cursor.ibeam", value: "editor") { EditorBehaviorSettings() }
            Tab("Privacy", systemImage: "hand.raised", value: "privacy") { PrivacySettings() }
            Tab("Shortcuts", systemImage: "command", value: "shortcuts") { ShortcutsSettings() }
            Tab("About", systemImage: "info.circle", value: "about") { AboutSettings() }
        }
        .frame(width: 600, height: 560)
    }
}

// MARK: - Building blocks

/// A System Settings style row: coloured icon tile, title, explanation, control on the trailing edge.
struct SettingRow<Control: View>: View {
    var icon: String
    var color: Color
    var title: String
    var detail: String? = nil
    @ViewBuilder var control: () -> Control

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            SettingIcon(symbol: icon, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail {
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            control()
        }
        .padding(.vertical, 2)
    }
}

struct SettingIcon: View {
    var symbol: String
    var color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(color.gradient))
            .accessibilityHidden(true)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @AppStorage(Pref.theme) private var theme = AppTheme.system
    @AppStorage(Pref.accent) private var accent = AccentChoice.system
    @AppStorage(Pref.accentCustom) private var accentCustom = ""
    @AppStorage(Pref.showStatusBar) private var showStatusBar = true
    @AppStorage(Pref.reopenLastNote) private var reopenLastNote = true
    @AppStorage(Pref.newNoteExtension) private var newNoteExtension = "md"

    private var customColor: Binding<Color> {
        Binding(
            get: { Color(nsColor: NSColor(hex: accentCustom) ?? .controlAccentColor) },
            set: { color in
                accentCustom = NSColor(color).hexString
                withAnimation(GlassStyle.snappy) { accent = .custom }
            })
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 18) {
                    ForEach(AppTheme.allCases) { option in
                        AppearanceThumbnail(theme: option, selected: theme == option, accent: accent.color) {
                            withAnimation(GlassStyle.snappy) { theme = option }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            } header: {
                Label("Appearance", systemImage: "circle.lefthalf.filled")
            }

            Section {
                HStack(spacing: 10) {
                    ForEach(AccentChoice.presets) { choice in
                        AccentSwatch(fill: choice == .system ? nil : choice.color, label: choice.label, selected: accent == choice) {
                            withAnimation(GlassStyle.snappy) { accent = choice }
                        }
                    }
                    Divider().frame(height: 20)
                    ColorPicker("Custom", selection: customColor, supportsOpacity: false)
                        .labelsHidden()
                        .overlay {
                            if accent == .custom {
                                Circle().strokeBorder(.primary.opacity(0.6), lineWidth: 2).padding(-4).allowsHitTesting(false)
                            }
                        }
                        .help("Pick a custom accent color")
                    Text("Custom")
                        .font(.callout)
                        .foregroundStyle(accent == .custom ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("Used for links, list markers, selections, the caret and controls throughout the app.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Label("Accent Color", systemImage: "paintpalette")
            }

            Section {
                SettingRow(icon: "clock.arrow.circlepath", color: .blue, title: "Reopen last note",
                           detail: "Pick up where you left off when Markly launches.") {
                    Toggle("", isOn: $reopenLastNote).labelsHidden().toggleStyle(.switch)
                }
                SettingRow(icon: "number", color: .gray, title: "Show word count",
                           detail: "Words, characters and reading time below the editor.") {
                    Toggle("", isOn: $showStatusBar).labelsHidden().toggleStyle(.switch)
                }
                SettingRow(icon: "doc.badge.plus", color: .indigo, title: "New note format",
                           detail: "File extension used when you create a note.") {
                    Picker("", selection: $newNoteExtension) {
                        Text(".md").tag("md")
                        Text(".markdown").tag("markdown")
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            } header: {
                Label("Notes", systemImage: "note.text")
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
            VStack(spacing: 7) {
                ZStack {
                    switch theme {
                    case .light: window(light: true)
                    case .dark: window(light: false)
                    case .system:
                        window(light: true)
                            .overlay(alignment: .trailing) {
                                window(light: false).mask(alignment: .trailing) { Rectangle().frame(width: 44) }
                            }
                    }
                }
                .frame(width: 88, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(selected ? accent : Color.primary.opacity(0.12), lineWidth: selected ? 2.5 : 1)
                }
                .shadow(color: .black.opacity(0.14), radius: 4, y: 1)
                .scaleEffect(selected ? 1 : 0.97)
                Text(theme == .system ? "Auto" : theme.label)
                    .font(.callout)
                    .foregroundStyle(selected ? .primary : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme == .system ? "Auto appearance" : "\(theme.label) appearance")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func window(light: Bool) -> some View {
        let bg = light ? Color(white: 0.97) : Color(white: 0.15)
        let bar = light ? Color(white: 0.87) : Color(white: 0.27)
        let line = light ? Color(white: 0.78) : Color(white: 0.38)
        return HStack(spacing: 0) {
            bar.frame(width: 22)
            VStack(alignment: .leading, spacing: 5) {
                Capsule().fill(line).frame(width: 36, height: 5)
                Capsule().fill(line).frame(width: 46, height: 3)
                Capsule().fill(accent.opacity(0.9)).frame(width: 26, height: 3)
                Spacer(minLength: 0)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(bg)
    }
}

private struct AccentSwatch: View {
    /// nil draws the multicolour "follow macOS" swatch.
    var fill: Color?
    var label: String
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(fill.map { AnyShapeStyle($0.gradient) }
                      ?? AnyShapeStyle(AngularGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .red], center: .center)))
                .frame(width: 20, height: 20)
                .overlay {
                    if selected { Circle().fill(.white).frame(width: 8, height: 8).transition(.scale) }
                }
                .overlay { Circle().strokeBorder(.black.opacity(0.1), lineWidth: 0.5) }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Editor behavior

private struct EditorBehaviorSettings: View {
    @AppStorage(Pref.smartLists) private var smartLists = true
    @AppStorage(Pref.selectionToolbar) private var selectionToolbar = true
    @AppStorage(Pref.syncPreview) private var syncPreview = true
    @AppStorage(Pref.typewriter) private var typewriter = false
    @AppStorage(Pref.focusParagraph) private var focusParagraph = false
    @AppStorage(Pref.animateTransitions) private var animateTransitions = true

    var body: some View {
        Form {
            Section {
                SettingRow(icon: "list.bullet", color: .orange, title: "Smart lists",
                           detail: "Return continues a list and numbers count up; Tab and ⇧Tab indent items.") {
                    Toggle("", isOn: $smartLists).labelsHidden().toggleStyle(.switch)
                }
                SettingRow(icon: "textformat", color: .blue, title: "Format bar on selection",
                           detail: "Select text to get bold, italic, links, headings and more in a floating bar.") {
                    Toggle("", isOn: $selectionToolbar).labelsHidden().toggleStyle(.switch)
                }
            } header: {
                Label("Writing", systemImage: "pencil.line")
            }

            Section {
                SettingRow(icon: "text.aligncenter", color: .teal, title: "Typewriter scrolling",
                           detail: "Keep the line you're writing in the middle of the window.") {
                    Toggle("", isOn: $typewriter).labelsHidden().toggleStyle(.switch)
                }
                SettingRow(icon: "text.line.first.and.arrowtriangle.forward", color: .purple, title: "Focus on paragraph",
                           detail: "Dim everything except the paragraph you're working on.") {
                    Toggle("", isOn: $focusParagraph).labelsHidden().toggleStyle(.switch)
                }
                SettingRow(icon: "arrow.up.and.down.text.horizontal", color: .green, title: "Sync preview scrolling",
                           detail: "Editor and preview scroll together, both ways. The preview follows the line you're editing; scroll either side and the other keeps up.") {
                    Toggle("", isOn: $syncPreview).labelsHidden().toggleStyle(.switch)
                }
                SettingRow(icon: "rectangle.2.swap", color: .pink, title: "Animate note transitions",
                           detail: "Cross-fade the editor when switching between notes.") {
                    Toggle("", isOn: $animateTransitions).labelsHidden().toggleStyle(.switch)
                }
            } header: {
                Label("Focus", systemImage: "scope")
            } footer: {
                Text("Font, size, spacing, width and syntax display are in the editor panel (⌥⌘I), next to the page they change.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Privacy

private struct PrivacySettings: View {
    @AppStorage(Pref.previewNetwork) private var previewNetwork = true
    @AppStorage(Pref.remoteImages) private var remoteImages = true

    var body: some View {
        Form {
            Section {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.green.gradient)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your notes stay on your Mac").font(.headline)
                        Text("Markly has no accounts, analytics or tracking. It reads and writes the files in the folders you add, and nothing else. The only network requests are the ones you allow below, plus Git sync when you press Sync.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                SettingRow(icon: "function", color: .blue, title: "Math and code styling in preview",
                           detail: "Loads KaTeX and highlight.js from cdn.jsdelivr.net. Off: the preview works fully offline without them.") {
                    Toggle("", isOn: $previewNetwork).labelsHidden().toggleStyle(.switch)
                }
                SettingRow(icon: "photo.on.rectangle", color: .orange, title: "Load images from the web",
                           detail: "Show images whose address starts with http or https. Off: only images stored on this Mac load, so opening a note never contacts a server.") {
                    Toggle("", isOn: $remoteImages).labelsHidden().toggleStyle(.switch)
                }
            } header: {
                Label("Network", systemImage: "network")
            } footer: {
                Text("Enforced with a Content-Security-Policy in the preview and in exported HTML.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Shortcuts

private struct ShortcutsSettings: View {
    private let groups: [(String, String, [(String, String)])] = [
        ("Formatting", "bold.italic.underline", [("Bold", "⌘B"), ("Italic", "⌘I"), ("Strikethrough", "⇧⌘X"), ("Highlight", "⇧⌘H"),
                                                 ("Inline code", "⌘E"), ("Link", "⌘K"), ("Code block", "⌥⌘C"), ("Table", "⌥⌘T")]),
        ("Blocks", "text.justify.left", [("Heading 1–4", "⌥⌘1–4"), ("Body text", "⌥⌘0"), ("Bulleted list", "⇧⌘8"),
                                        ("Numbered list", "⇧⌘7"), ("Task list", "⇧⌘T"), ("Quote", "⌘'"), ("Indent / outdent", "⇥ / ⇧⇥")]),
        ("Navigation", "arrow.triangle.turn.up.right.diamond", [("Open note 1–9", "⌘1–9"), ("Add folder", "⌘O"), ("New note", "⌘N"),
                                                                ("Find", "⌘F"), ("Filter notes", "⇧⌘L"), ("Preview", "⌥⌘P"),
                                                                ("Focus mode", "⇧⌘F"), ("Text size", "⌘+ / ⌘−")]),
        ("Windows", "macwindow", [("Editor settings", "⌥⌘I"), ("App settings", "⌘,")]),
    ]

    var body: some View {
        Form {
            ForEach(groups, id: \.0) { group in
                Section {
                    ForEach(group.2, id: \.0) { item in
                        LabeledContent(item.0) {
                            Text(item.1)
                                .font(.system(.body, design: .rounded).weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label(group.0, systemImage: group.1)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - About

private struct AboutSettings: View {
    @State private var showNotices = false
    @State private var confirmReset = false
    @State private var copied = false

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Markly").font(.system(size: 22, weight: .regular, design: .serif))
                        Text(version).foregroundStyle(.secondary)
                        Text("Free and open source under the MIT License.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }

            Section {
                Button { showNotices = true } label: {
                    SettingRow(icon: "shippingbox", color: .brown, title: "Open Source Notices",
                               detail: "Libraries Markly is built with, and their licenses.") {
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                SettingRow(icon: "stethoscope", color: .green, title: "Copy Diagnostics",
                           detail: "Version and system details for a bug report. No note content or file names.") {
                    Button(copied ? "Copied" : "Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(Self.diagnostics(version: version), forType: .string)
                        withAnimation(GlassStyle.snappy) { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { copied = false } }
                    }
                    .contentTransition(.interpolate)
                }
            } header: {
                Label("Support", systemImage: "lifepreserver")
            }

            Section {
                SettingRow(icon: "arrow.counterclockwise", color: .red, title: "Reset All Settings",
                           detail: "Restore every preference to its default. Your notes and sidebar folders are kept.") {
                    Button("Reset…", role: .destructive) { confirmReset = true }
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showNotices) { NoticesSheet() }
        .confirmationDialog("Reset all settings?", isPresented: $confirmReset) {
            Button("Reset All Settings", role: .destructive) {
                Pref.all.forEach { UserDefaults.standard.removeObject(forKey: $0) }
                AppTheme.system.apply()
            }
        } message: {
            Text("Appearance, editor and privacy preferences return to their defaults. Notes and folders are not affected.")
        }
    }

    static func diagnostics(version: String) -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        #if arch(arm64)
        let arch = "Apple silicon"
        #else
        let arch = "Intel"
        #endif
        let prefs = [Pref.theme, Pref.syntax, Pref.imagePreview, Pref.typewriter, Pref.focusParagraph,
                     Pref.smartLists, Pref.previewNetwork, Pref.remoteImages]
            .map { "\($0)=\(UserDefaults.standard.object(forKey: $0).map { "\($0)" } ?? "default")" }
            .joined(separator: ", ")
        return "Markly \(version)\nmacOS \(os) · \(arch)\nSettings: \(prefs)"
    }
}

private struct NoticesSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let notices: [(String, String, String)] = [
        ("swift-markdown", "Apache License 2.0", "Markdown parsing and HTML rendering. © Apple Inc. and the Swift project authors."),
        ("swift-cmark (cmark-gfm)", "BSD 2-Clause", "GitHub Flavored Markdown parser. © John MacFarlane, GitHub."),
        ("KaTeX", "MIT License", "Math typesetting in the preview, loaded from jsDelivr when allowed. © Khan Academy and contributors."),
        ("highlight.js", "BSD 3-Clause", "Code colouring in the preview, loaded from jsDelivr when allowed. © Ivan Sagalaev and contributors."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Open Source Notices").font(.title2.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)
            }
            ForEach(notices, id: \.0) { notice in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(notice.0).font(.headline)
                        Text(notice.1)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill(.quaternary))
                    }
                    Text(notice.2).font(.callout).foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}

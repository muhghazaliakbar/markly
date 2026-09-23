import SwiftUI

/// The floating appearance panel on the right of the editor.
struct InspectorPanel: View {
    @EnvironmentObject var workspace: Workspace
    @ObservedObject var git: GitModel
    var onSliderEditing: (Bool) -> Void = { _ in }

    @AppStorage(Pref.font) private var font = FontChoice.sans
    @AppStorage(Pref.fontSize) private var fontSize = 16.0
    @AppStorage(Pref.lineSpacing) private var lineSpacing = 1.4
    @AppStorage(Pref.editorWidth) private var editorWidth = 720.0
    @AppStorage(Pref.syntax) private var syntax = SyntaxVisibility.focused
    @AppStorage(Pref.theme) private var theme = AppTheme.system
    @AppStorage(Pref.accent) private var accent = AccentChoice.system
    @AppStorage(Pref.spellCheck) private var spellCheck = true
    @AppStorage(Pref.showStatusBar) private var showStatusBar = true
    @AppStorage(Pref.imagePreview) private var imagePreview = ImagePreview.medium

    @State private var showShortcuts = false
    @State private var showGitStatus = false

    private var tint: Color { accent.color }

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 6) {
                VStack(spacing: 12) {
                    GlassSegmented(
                        options: AppTheme.allCases.map { .init(value: $0, icon: $0.icon, help: $0.label) },
                        selection: $theme, accent: tint)

                    tiles

                    GlassSegmented(
                        options: SyntaxVisibility.allCases.map { .init(value: $0, icon: $0.icon, label: $0.label, help: $0.help) },
                        selection: $syntax, accent: tint)

                    TickSlider(title: "Line spacing", value: $lineSpacing, range: 1.0...2.2, step: 0.1, accent: tint,
                               onEditing: onSliderEditing) {
                        String(format: "%.1f", $0)
                    }

                    TickSlider(title: "Editor width", value: $editorWidth, range: 480...1360, step: 80, accent: tint,
                               onEditing: onSliderEditing) {
                        "\(Int(($0 - 480) / 880 * 60 + 40))%"
                    }

                    accentRow

                    HStack(spacing: 8) {
                        GlassChip(title: "Spelling", icon: "textformat.abc.dottedunderline", isOn: $spellCheck, accent: tint)
                        GlassChip(title: "Word count", icon: "number", isOn: $showStatusBar, accent: tint)
                    }

                    gitCard

                    Button { showShortcuts = true } label: {
                        HStack {
                            Image(systemName: "command")
                            Text("Keyboard Shortcuts")
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 16)
                        .frame(height: 40)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Capsule())
                }
                .padding(14)
            }
        }
        .scrollIndicators(.never)
        // The cards are glass already; the toolbar's scroll-edge backing would paint a mismatched
        // rectangle above the panel.
        .scrollEdgeEffectHidden(true, for: .top)
        .frame(width: 312)
        .onChange(of: theme) { _, t in t.apply() }
        .sheet(isPresented: $showShortcuts) { ShortcutsSheet() }
    }

    // MARK: Tiles

    private var tiles: some View {
        HStack(spacing: 10) {
            let size = TextSize.nearest(fontSize)
            GlassTile(active: size != .medium, accent: tint, count: TextSize.allCases.count, index: size.index,
                      help: "Text size: \(size.label)", action: { fontSize = size.next.rawValue }) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("A").font(.system(size: 18 + CGFloat(size.index) * 5, weight: .regular))
                    Image(systemName: "arrow.up").font(.system(size: 11, weight: .bold))
                }
            }
            .contextMenu {
                ForEach(TextSize.allCases) { s in Button(s.label) { fontSize = s.rawValue } }
            }

            GlassTile(active: imagePreview != .off, accent: tint, count: 3, index: max(0, imagePreview.index - 1),
                      help: "Image previews: \(imagePreview.label)", action: { imagePreview = imagePreview.next }) {
                Image(systemName: imagePreview == .off ? "photo.badge.minus" : "photo")
                    .font(.system(size: 22 + CGFloat(max(0, imagePreview.index - 1)) * 4, weight: .regular))
            }
            .contextMenu {
                ForEach(ImagePreview.allCases) { p in Button(p.label) { imagePreview = p } }
            }

            GlassTile(active: font != .sans, accent: tint, count: FontChoice.allCases.count, index: font.index,
                      help: "Typeface: \(font.label)", action: { font = font.next }) {
                Text("Aa").font(.system(size: 30, weight: .regular, design: font.design))
            }
            .contextMenu {
                ForEach(FontChoice.allCases) { f in Button(f.label) { font = f } }
            }
        }
    }

    // MARK: Accent

    private var accentRow: some View {
        HStack(spacing: 0) {
            ForEach(AccentChoice.allCases) { choice in
                Button {
                    withAnimation(GlassStyle.snappy) { accent = choice }
                    GlassStyle.tick()
                } label: {
                    Circle()
                        .fill(choice == .system
                              ? AnyShapeStyle(AngularGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .red], center: .center))
                              : AnyShapeStyle(choice.color.gradient))
                        .frame(width: 18, height: 18)
                        .overlay {
                            if accent == choice {
                                Circle().fill(.white).frame(width: 7, height: 7).transition(.scale)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(choice.label)
            }
        }
        .padding(.horizontal, 8)
        .glassEffect(.regular, in: Capsule())
    }

    // MARK: Git

    private var gitCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: gitIcon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(gitIconStyle)
                    .frame(width: 22)
                    .symbolEffect(.rotate, isActive: git.busy)
                VStack(alignment: .leading, spacing: 2) {
                    Text(gitTitle).font(.system(size: 13, weight: .semibold))
                    Text(git.message ?? gitSubtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                switch git.state {
                case .noFolder:
                    EmptyView()
                case .notRepository:
                    Button { git.initialize() } label: {
                        Label("Initialize Git", systemImage: "plus").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                case .repository:
                    Button {
                        workspace.save()
                        git.sync()
                    } label: {
                        Label(git.busy ? "Syncing…" : "Sync", systemImage: "arrow.triangle.2.circlepath").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(tint)
                    .disabled(git.busy)
                    Button { showGitStatus.toggle() } label: {
                        Label("Status", systemImage: "sparkle").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .popover(isPresented: $showGitStatus, arrowEdge: .leading) {
                        ScrollView {
                            Text(git.statusText.isEmpty ? "Clean working tree" : git.statusText)
                                .font(.system(size: 11, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                        }
                        .frame(width: 320, height: 220)
                    }
                }
            }
            .controlSize(.large)
        }
        .padding(14)
        .glassEffect(.regular, in: GlassStyle.card)
    }

    private var gitIcon: String {
        switch git.state {
        case .noFolder: "folder"
        case .notRepository: "link"
        case .repository: git.busy ? "arrow.triangle.2.circlepath" : "arrow.triangle.branch"
        }
    }

    private var gitIconStyle: AnyShapeStyle {
        if case .repository(_, let changes, _) = git.state, changes == 0 { return AnyShapeStyle(.green) }
        return AnyShapeStyle(.secondary)
    }

    private var gitTitle: String {
        switch git.state {
        case .noFolder: "Git Sync"
        case .notRepository: "Connect Git"
        case .repository(let branch, let changes, _):
            changes == 0 ? "\(branch) · Up to date" : "\(branch) · \(changes) change\(changes == 1 ? "" : "s")"
        }
    }

    private var gitSubtitle: String {
        switch git.state {
        case .noFolder: "Open a note to see its repository."
        case .notRepository: "Track this folder with Git to sync it with GitHub or any remote."
        case .repository(_, _, let remote): remote ?? "No remote yet · commits stay on this Mac"
        }
    }
}

struct ShortcutsSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let groups: [(String, [(String, String)])] = [
        ("Formatting", [("Bold", "⌘B"), ("Italic", "⌘I"), ("Strikethrough", "⇧⌘X"), ("Highlight", "⇧⌘H"),
                        ("Inline code", "⌘E"), ("Link", "⌘K"), ("Code block", "⌥⌘C"), ("Table", "⌥⌘T")]),
        ("Blocks", [("Heading 1–4", "⌥⌘1–4"), ("Body text", "⌥⌘0"), ("Bulleted list", "⇧⌘8"),
                    ("Numbered list", "⇧⌘7"), ("Task list", "⇧⌘T"), ("Quote", "⌘'"), ("Indent / outdent", "⇥ / ⇧⇥")]),
        ("Navigation", [("Open file 1–9", "⌘1–9"), ("Add folder", "⌘O"), ("New file", "⌘N"), ("Find", "⌘F"),
                        ("Preview", "⌥⌘P"), ("Focus mode", "⇧⌘F"), ("Appearance panel", "⌘,"), ("Text size", "⌘+ / ⌘−")]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Keyboard Shortcuts").font(.title2.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.glassProminent).keyboardShortcut(.defaultAction)
            }
            HStack(alignment: .top, spacing: 28) {
                ForEach(groups, id: \.0) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.0.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        ForEach(group.1, id: \.0) { item in
                            HStack {
                                Text(item.0)
                                Spacer(minLength: 16)
                                Text(item.1).font(.system(.body, design: .rounded).weight(.medium)).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(width: 200)
                }
            }
        }
        .padding(24)
    }
}

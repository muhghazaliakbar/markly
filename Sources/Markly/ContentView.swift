import SwiftUI

struct ContentView: View {
    @EnvironmentObject var workspace: Workspace
    @StateObject private var git = GitModel()

    @AppStorage(Pref.font) private var font = FontChoice.sans
    @AppStorage(Pref.fontSize) private var fontSize = 16.0
    @AppStorage(Pref.lineSpacing) private var lineSpacing = 1.4
    @AppStorage(Pref.editorWidth) private var editorWidth = 720.0
    @AppStorage(Pref.syntax) private var syntax = SyntaxVisibility.focused
    @AppStorage(Pref.accent) private var accent = AccentChoice.system
    @AppStorage(Pref.spellCheck) private var spellCheck = true
    @AppStorage(Pref.showStatusBar) private var showStatusBar = true
    @AppStorage(Pref.imagePreview) private var imagePreview = ImagePreview.medium

    @State private var columns = NavigationSplitViewVisibility.all

    private var style: EditorStyle {
        EditorStyle(font: font, fontSize: fontSize, lineSpacing: lineSpacing, maxWidth: editorWidth,
                    syntax: syntax, accent: accent, spellCheck: spellCheck, imagePreview: imagePreview)
    }

    var body: some View {
        Group {
            if !workspace.hasFolders {
                WelcomeView()
            } else {
                NavigationSplitView(columnVisibility: $columns) {
                    SidebarView()
                        .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 420)
                        .background { BehindWindowBlur().ignoresSafeArea() }
                } detail: {
                    detail
                }
            }
        }
        .tint(accent.color)
        .onChange(of: workspace.focusMode) { _, on in
            withAnimation(GlassStyle.spring) { columns = on ? .detailOnly : .all }
        }
        .onChange(of: workspace.currentURL, initial: true) { _, url in
            git.refresh(folder: url?.deletingLastPathComponent() ?? workspace.roots.first)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            git.refresh(folder: workspace.currentURL?.deletingLastPathComponent() ?? workspace.roots.first)
        }
        .alert("Something went wrong", isPresented: Binding(get: { workspace.errorMessage != nil },
                                                           set: { if !$0 { workspace.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(workspace.errorMessage ?? "")
        }
    }

    private var showPanel: Bool { workspace.showInspector && !workspace.focusMode }

    @ViewBuilder
    private var detail: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                if let url = workspace.currentURL {
                    HSplitView {
                        EditorView(text: $workspace.text, style: style, baseURL: url.deletingLastPathComponent(),
                                   onOpenLink: { workspace.followLink($0) })
                            .id(url)
                            .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
                        if workspace.showPreview {
                            PreviewView(markdown: workspace.text, fileURL: url, accent: accent.nsColor)
                                .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    if showStatusBar && !workspace.focusMode {
                        StatusPill()
                            .padding(.bottom, 14)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                } else {
                    EmptyEditor()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .topTrailing) {
                if workspace.focusMode {
                    Button { workspace.focusMode = false } label: {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .frame(width: 34, height: 34).contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .padding(16)
                    .help("Exit Focus Mode (⇧⌘F)")
                    .transition(.scale.combined(with: .opacity))
                }
            }

            if showPanel {
                InspectorPanel(git: git)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(GlassStyle.spring, value: showPanel)
        .animation(GlassStyle.spring, value: workspace.showPreview)
        .background(Color(nsColor: .textBackgroundColor))
        .navigationTitle(workspace.currentURL?.deletingPathExtension().lastPathComponent ?? "Markly")
        .toolbar { toolbar }
        .toolbar(workspace.focusMode ? .hidden : .visible, for: .windowToolbar)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            if let url = workspace.currentURL {
                HStack(spacing: 6) {
                    Text(url.deletingPathExtension().lastPathComponent).font(.system(size: 13, weight: .semibold))
                    if workspace.isDirty {
                        Circle().fill(.secondary).frame(width: 5, height: 5).transition(.scale)
                    }
                }
                .padding(.horizontal, 10)
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button { workspace.newFile() } label: { Label("New File", systemImage: "square.and.pencil") }
                .help("New File (⌘N)")
            Toggle(isOn: $workspace.showPreview) { Label("Preview", systemImage: "doc.richtext") }
                .help("Toggle Preview (⌥⌘P)")
                .disabled(workspace.currentURL == nil)
            Button { workspace.focusMode.toggle() } label: { Label("Focus", systemImage: "arrow.up.left.and.arrow.down.right") }
                .help("Focus Mode (⇧⌘F)")
                .disabled(workspace.currentURL == nil)
        }
        ToolbarSpacer(.fixed, placement: .primaryAction)
        ToolbarItem(placement: .primaryAction) {
            Toggle(isOn: $workspace.showInspector.animation(GlassStyle.spring)) {
                Label("Appearance", systemImage: "textformat.size")
            }
            .help("Appearance (⌘,)")
        }
    }
}

struct StatusPill: View {
    @EnvironmentObject var workspace: Workspace

    var body: some View {
        let s = workspace.stats
        HStack(spacing: 12) {
            Text("\(s.words) word\(s.words == 1 ? "" : "s")")
            Divider().frame(height: 10)
            Text("\(s.characters) char\(s.characters == 1 ? "" : "s")")
            Divider().frame(height: 10)
            Text("\(s.minutes) min read")
        }
        .font(.system(size: 11, weight: .medium).monospacedDigit())
        .foregroundStyle(.secondary)
        .contentTransition(.numericText())
        .padding(.horizontal, 14)
        .frame(height: 28)
        .glassEffect(.regular, in: Capsule())
    }
}

struct EmptyEditor: View {
    @EnvironmentObject var workspace: Workspace

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No note selected").font(.title3.weight(.medium))
            Text("Pick a note in the sidebar, or start a new one.")
                .foregroundStyle(.secondary)
            Button { workspace.newFile() } label: {
                Label("New Note", systemImage: "square.and.pencil").padding(.horizontal, 6)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WelcomeView: View {
    @EnvironmentObject var workspace: Workspace
    @State private var appeared = false

    var body: some View {
        ZStack {
            MeshGradient(width: 3, height: 3, points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.6, 0.45], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ], colors: [
                .indigo.opacity(0.35), .blue.opacity(0.25), .cyan.opacity(0.2),
                .purple.opacity(0.2), .clear, .blue.opacity(0.15),
                .pink.opacity(0.15), .indigo.opacity(0.2), .teal.opacity(0.2),
            ])
            .ignoresSafeArea()

            GlassEffectContainer(spacing: 20) {
                VStack(spacing: 22) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable().frame(width: 112, height: 112)
                        .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
                        .scaleEffect(appeared ? 1 : 0.8)
                    VStack(spacing: 6) {
                        Text("Markly").font(.system(size: 40, weight: .regular, design: .serif))
                        Text("A calm, open-source Markdown editor for your folders.")
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 12) {
                        Button { workspace.showOpenFolderPanel() } label: {
                            Label("Add Folder…", systemImage: "folder.badge.plus").padding(.horizontal, 6)
                        }
                        .buttonStyle(.glassProminent)
                        .keyboardShortcut("o")
                        Button { workspace.showOpenFilePanel() } label: {
                            Label("Open File…", systemImage: "doc").padding(.horizontal, 6)
                        }
                        .buttonStyle(.glass)
                    }
                    .controlSize(.extraLarge)
                }
                .padding(48)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
                .opacity(appeared ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Markly")
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { appeared = true } }
    }
}

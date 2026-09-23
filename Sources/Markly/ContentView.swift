import SwiftUI

struct ContentView: View {
    @EnvironmentObject var workspace: Workspace

    @AppStorage(Pref.font) private var font = FontChoice.sans
    @AppStorage(Pref.fontSize) private var fontSize = 16.0
    @AppStorage(Pref.lineSpacing) private var lineSpacing = 1.4
    @AppStorage(Pref.editorWidth) private var editorWidth = 720.0
    @AppStorage(Pref.syntax) private var syntax = SyntaxVisibility.focused
    @AppStorage(Pref.accent) private var accent = AccentChoice.system
    @AppStorage(Pref.spellCheck) private var spellCheck = true
    @AppStorage(Pref.showStatusBar) private var showStatusBar = true

    @State private var columns = NavigationSplitViewVisibility.all

    private var style: EditorStyle {
        EditorStyle(font: font, fontSize: fontSize, lineSpacing: lineSpacing, maxWidth: editorWidth,
                    syntax: syntax, accent: accent, spellCheck: spellCheck)
    }

    var body: some View {
        Group {
            if workspace.rootURL == nil {
                WelcomeView()
            } else {
                NavigationSplitView(columnVisibility: $columns) {
                    SidebarView()
                        .navigationSplitViewColumnWidth(min: 180, ideal: 240, max: 400)
                } detail: {
                    detail
                }
            }
        }
        .tint(accent.color)
        .onChange(of: workspace.focusMode) { _, on in
            withAnimation { columns = on ? .detailOnly : .all }
        }
        .alert("Something went wrong", isPresented: Binding(get: { workspace.errorMessage != nil },
                                                           set: { if !$0 { workspace.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(workspace.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let url = workspace.currentURL {
            HSplitView {
                EditorView(text: $workspace.text, style: style, onOpenLink: { workspace.followLink($0) })
                    .id(url)
                    .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
                if workspace.showPreview {
                    PreviewView(markdown: workspace.text, fileURL: url, accent: accent.nsColor)
                        .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if showStatusBar && !workspace.focusMode { StatusBar() }
            }
            .navigationTitle(url.deletingPathExtension().lastPathComponent)
            .navigationSubtitle(workspace.isDirty ? "Edited" : relativeFolder(url))
            .toolbar { toolbar }
            .toolbar(workspace.focusMode ? .hidden : .visible, for: .windowToolbar)
        } else {
            ContentUnavailableView {
                Label("No File Selected", systemImage: "doc.text")
            } description: {
                Text("Pick a file in the sidebar or create a new one.")
            } actions: {
                Button("New File") { workspace.newFile() }
                    .keyboardShortcut("n")
            }
            .navigationTitle(workspace.rootURL?.lastPathComponent ?? "Markly")
            .toolbar { toolbar }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button { workspace.newFile() } label: { Label("New File", systemImage: "square.and.pencil") }
                .help("New File (⌘N)")
            Toggle(isOn: $workspace.showPreview) { Label("Preview", systemImage: "sidebar.right") }
                .help("Toggle Preview (⌥⌘P)")
                .disabled(workspace.currentURL == nil)
            Button { workspace.focusMode.toggle() } label: { Label("Focus", systemImage: "arrow.up.left.and.arrow.down.right") }
                .help("Focus Mode (⇧⌘F)")
                .disabled(workspace.currentURL == nil)
        }
    }

    private func relativeFolder(_ url: URL) -> String {
        guard let root = workspace.rootURL else { return "" }
        let rel = url.deletingLastPathComponent().path.replacingOccurrences(of: root.path, with: "")
        return root.lastPathComponent + rel
    }
}

struct StatusBar: View {
    @EnvironmentObject var workspace: Workspace

    var body: some View {
        let s = workspace.stats
        HStack(spacing: 14) {
            Spacer()
            Text("\(s.words) words")
            Text("\(s.characters) characters")
            Text("\(s.minutes) min read")
        }
        .font(.caption)
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(Color(nsColor: .textBackgroundColor))
    }
}

struct WelcomeView: View {
    @EnvironmentObject var workspace: Workspace

    var body: some View {
        VStack(spacing: 22) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 96, height: 96)
            VStack(spacing: 6) {
                Text("Markly").font(.largeTitle.weight(.semibold))
                Text("A calm, open-source Markdown editor for your folders.")
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Button("Open Folder…") { workspace.showOpenFolderPanel() }
                    .keyboardShortcut("o")
                    .buttonStyle(.borderedProminent)
                Button("Open File…") { workspace.showOpenFilePanel() }
            }
            .controlSize(.large)

            let recents = workspace.recentFolders.filter { FileManager.default.fileExists(atPath: $0.path) }
            if !recents.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent").font(.caption).foregroundStyle(.secondary).padding(.leading, 8)
                    ForEach(recents, id: \.self) { url in
                        Button { workspace.openFolder(url) } label: {
                            HStack {
                                Image(systemName: "folder").foregroundStyle(.tint)
                                Text(url.lastPathComponent)
                                Spacer()
                                Text(url.deletingLastPathComponent().path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                                    .foregroundStyle(.secondary).lineLimit(1).truncationMode(.head)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: 420)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Markly")
    }
}

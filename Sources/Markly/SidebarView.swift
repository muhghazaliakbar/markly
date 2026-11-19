import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var workspace: Workspace
    @ObservedObject var git: GitModel
    @Environment(\.openSettings) private var openSettings
    @State private var query = ""
    @State private var renaming: FileNode?
    @State private var newName = ""
    @State private var searching = false
    @FocusState private var searchFocused: Bool
    /// Matches inside the notes' text, found off the main thread after a short pause in typing.
    @State private var textHits: [NoteSearch.Hit] = []
    @State private var searchingText = false

    private var results: [FileNode] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return workspace.allFiles.filter {
            $0.name.localizedCaseInsensitiveContains(q) || $0.url.path.localizedCaseInsensitiveContains(q)
        }
    }

    private var shortcutIndex: [URL: Int] {
        Dictionary(uniqueKeysWithValues: workspace.quickFiles.enumerated().map { ($1, $0 + 1) })
    }

    var body: some View {
        List(selection: $workspace.selection) {
            if !query.isEmpty {
                if !results.isEmpty {
                    Section {
                        ForEach(results) { node in row(node, showPath: true) }
                    } header: {
                        Text(results.count == 1 ? "1 note" : "\(results.count) notes")
                    }
                }
                Section {
                    ForEach(textHits) { hit in hitRow(hit) }
                } header: {
                    if searchingText && textHits.isEmpty {
                        Text("Searching…")
                    } else if !textHits.isEmpty {
                        Text(textHits.count == 1 ? "1 match in text" : "\(textHits.count) matches in text")
                    } else if results.isEmpty {
                        Text("No results")
                    }
                }
            } else {
                ForEach(workspace.roots, id: \.self) { root in
                    Section {
                        if !workspace.collapsed.contains(root) {
                            let tree = workspace.trees[root] ?? []
                            if tree.isEmpty {
                                Button { workspace.newFile(in: root) } label: {
                                    Label("New note", systemImage: "plus").foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            } else {
                                OutlineGroup(tree, children: \.children) { node in row(node) }
                            }
                        }
                    } header: {
                        rootHeader(root)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            if searching {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search notes", text: $query)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                        .onSubmit { openFirstResult() }
                        .onExitCommand { closeSearch() }
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 32)
                .glassEffect(.regular, in: Capsule())
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .background {
            // ⌘⇧L opens the search field.
            Button("") { toggleSearch() }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                .hidden()
        }
        .task(id: query) { await searchText() }
        .alert("Rename", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Rename") { if let r = renaming { workspace.rename(r, to: newName) }; renaming = nil }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }

    private func toggleSearch() {
        withAnimation(GlassStyle.spring) { searching.toggle() }
        if searching { searchFocused = true } else { query = "" }
    }

    private func searchText() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { textHits = []; searchingText = false; return }
        searchingText = true
        // Wait for a pause in typing; a newer query cancels this task.
        try? await Task.sleep(for: .milliseconds(150))
        guard !Task.isCancelled else { return }
        let files = workspace.allFiles.map(\.url)
        var overrides: [URL: String] = [:]
        if let current = workspace.currentURL, workspace.isDirty { overrides[current] = workspace.text }
        let hits = await Self.search(q, in: files, overrides: overrides)
        guard !Task.isCancelled else { return }
        textHits = hits
        searchingText = false
    }

    /// Nonisolated so the file reads run off the main thread; cancelled with the calling task.
    nonisolated private static func search(_ q: String, in files: [URL], overrides: [URL: String]) async -> [NoteSearch.Hit] {
        NoteSearch.search(q, in: files, overrides: overrides, isCancelled: { Task.isCancelled })
    }

    private func openFirstResult() {
        if let first = results.first { workspace.selection = first.url }
        else if let hit = textHits.first { workspace.show(hit.range, in: hit.url) }
    }

    private func closeSearch() {
        withAnimation(GlassStyle.spring) { searching = false }
        query = ""
    }

    // MARK: Parts

    private func rootHeader(_ root: URL) -> some View {
        let collapsed = workspace.collapsed.contains(root)
        return Button {
            withAnimation(GlassStyle.spring) { workspace.toggleCollapsed(root) }
        } label: {
            HStack(spacing: 6) {
                Text(root.lastPathComponent)
                    .font(.system(size: 19, weight: .regular, design: .serif))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(collapsed ? -90 : 0))
                    .animation(GlassStyle.snappy, value: collapsed)
            }
            .padding(.top, 6)
            .padding(.bottom, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .textCase(nil)
        .contextMenu {
            Button("New File") { workspace.newFile(in: root) }
            Button("New Folder") { workspace.newFolder(in: root) }
            Divider()
            Button("Reveal in Finder") { workspace.revealInFinder(root) }
            Button("Refresh") { workspace.refresh() }
            Divider()
            Button("Remove from Sidebar") { withAnimation(GlassStyle.spring) { workspace.removeFolder(root) } }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            Button { workspace.showOpenFolderPanel() } label: {
                Label("Add folder", systemImage: "folder.badge.plus")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Capsule())
            .help("Add a folder to the sidebar (⌘O)")

            Spacer()

            Button { toggleSearch() } label: {
                Image(systemName: "magnifyingglass").frame(width: 32, height: 32).contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Circle())
            .help("Search notes (⇧⌘L)")

            GitSidebarButton(git: git)

            Button { openSettings() } label: {
                Image(systemName: "gearshape")
                    .frame(width: 32, height: 32).contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Circle())
            .help("Settings (⌘,)")
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func row(_ node: FileNode, showPath: Bool = false) -> some View {
        Group {
            if node.isDirectory {
                Label(node.name, systemImage: "folder")
            } else {
                let isCurrent = workspace.currentURL == node.url
                Label {
                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(node.name).lineLimit(1)
                            if showPath {
                                Text(relativePath(node.url))
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        if isCurrent && workspace.isDirty {
                            Circle().fill(.secondary).frame(width: 5, height: 5)
                        }
                        Spacer(minLength: 4)
                        if let n = shortcutIndex[node.url] {
                            Text("⌘\(n)")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.tertiary)
                        }
                    }
                } icon: {
                    Image(systemName: isCurrent ? "arrow.right" : "doc.text")
                        .contentTransition(.symbolEffect(.replace))
                }
                .tag(node.url)
            }
        }
        .contextMenu {
            if node.isDirectory {
                Button("New File") { workspace.newFile(in: node.url) }
                Button("New Folder") { workspace.newFolder(in: node.url) }
                Divider()
            }
            Button("Rename…") { newName = node.isDirectory ? node.name : node.url.lastPathComponent; renaming = node }
            Button("Reveal in Finder") { workspace.revealInFinder(node.url) }
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(node.url.path, forType: .string)
            }
            Divider()
            Button("Move to Trash", role: .destructive) { workspace.moveToTrash(node) }
        }
    }

    private func hitRow(_ hit: NoteSearch.Hit) -> some View {
        Button { workspace.show(hit.range, in: hit.url) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(highlighted(hit))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(hit.url.deletingPathExtension().lastPathComponent)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(relativePath(hit.url) + "/" + hit.url.lastPathComponent)
    }

    private func highlighted(_ hit: NoteSearch.Hit) -> AttributedString {
        var text = AttributedString(hit.snippet)
        text.foregroundColor = .secondary
        if let r = Range(hit.snippetMatch, in: hit.snippet), let ar = Range(r, in: text) {
            text[ar].foregroundColor = .primary
            text[ar].font = .body.weight(.semibold)
        }
        return text
    }

    private func relativePath(_ url: URL) -> String {
        guard let root = workspace.root(containing: url) else { return "" }
        let rel = url.deletingLastPathComponent().path.replacingOccurrences(of: root.path, with: "")
        return root.lastPathComponent + rel
    }
}

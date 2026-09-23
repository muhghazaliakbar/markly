import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var workspace: Workspace
    @State private var query = ""
    @State private var renaming: FileNode?
    @State private var newName = ""

    private var results: [FileNode] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return workspace.tree.flatMap(\.allFiles).filter {
            $0.name.localizedCaseInsensitiveContains(q) || $0.url.path.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        List(selection: $workspace.selection) {
            if query.isEmpty {
                Section(workspace.rootURL?.lastPathComponent ?? "Files") {
                    OutlineGroup(workspace.tree, children: \.children) { node in
                        row(node)
                    }
                }
            } else {
                Section("Results") {
                    ForEach(results) { node in row(node, showPath: true) }
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $query, placement: .sidebar, prompt: "Filter")
        .contextMenu {
            Button("New File") { workspace.newFile(in: workspace.rootURL) }
            Button("New Folder") { workspace.newFolder(in: workspace.rootURL) }
            Divider()
            Button("Refresh") { workspace.refresh() }
        }
        .alert("Rename", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $newName)
            Button("Rename") { if let r = renaming { workspace.rename(r, to: newName) }; renaming = nil }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button { workspace.newFile() } label: { Image(systemName: "square.and.pencil") }
                    .help("New File")
                Button { workspace.newFolder() } label: { Image(systemName: "folder.badge.plus") }
                    .help("New Folder")
                Spacer()
                Button { workspace.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .help("Refresh")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func row(_ node: FileNode, showPath: Bool = false) -> some View {
        Group {
            if node.isDirectory {
                Label(node.name, systemImage: "folder")
            } else {
                Label {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text(node.name).lineLimit(1)
                            if workspace.currentURL == node.url && workspace.isDirty {
                                Circle().fill(.secondary).frame(width: 5, height: 5)
                            }
                        }
                        if showPath, let root = workspace.rootURL {
                            Text(node.url.deletingLastPathComponent().path.replacingOccurrences(of: root.path, with: "").trimmingCharacters(in: ["/"]))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                } icon: {
                    Image(systemName: "doc.text")
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
}

import AppKit
import SwiftUI
import UniformTypeIdentifiers

final class FileNode: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool
    var children: [FileNode]?

    var id: URL { url }
    var name: String { isDirectory ? url.lastPathComponent : url.deletingPathExtension().lastPathComponent }

    init(url: URL, isDirectory: Bool, children: [FileNode]? = nil) {
        self.url = url
        self.isDirectory = isDirectory
        self.children = children
    }

    static func == (a: FileNode, b: FileNode) -> Bool { a.url == b.url }
    func hash(into h: inout Hasher) { h.combine(url) }

    var allFiles: [FileNode] {
        isDirectory ? (children ?? []).flatMap(\.allFiles) : [self]
    }
}

@MainActor
final class Workspace: ObservableObject {
    static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd", "mdx", "txt"]
    static let ignoredFolders: Set<String> = ["node_modules", ".git", ".build", "DerivedData", "Pods"]

    @Published private(set) var rootURL: URL?
    @Published private(set) var tree: [FileNode] = []
    @Published var selection: URL? {
        didSet { if selection != oldValue, let s = selection { open(s) } }
    }
    @Published private(set) var currentURL: URL?
    @Published var text: String = "" {
        didSet { if text != oldValue && !loading { markDirty() } }
    }
    @Published private(set) var isDirty = false
    @Published var showPreview = UserDefaults.standard.bool(forKey: "showPreview") {
        didSet { UserDefaults.standard.set(showPreview, forKey: "showPreview") }
    }
    @Published var focusMode = false
    @Published var errorMessage: String?

    @AppStorage("recentFolders") private var recentData: Data = Data()
    @AppStorage("lastFile") private var lastFile: String = ""

    private var loading = false
    private var saveTask: Task<Void, Never>?
    private var loadedModDate: Date?

    var recentFolders: [URL] {
        ((try? JSONDecoder().decode([String].self, from: recentData)) ?? []).map { URL(fileURLWithPath: $0) }
    }

    init() {
        if let last = recentFolders.first, FileManager.default.fileExists(atPath: last.path) {
            openFolder(last)
            if !lastFile.isEmpty, FileManager.default.fileExists(atPath: lastFile),
               lastFile.hasPrefix(last.path) {
                selection = URL(fileURLWithPath: lastFile)
            }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkForExternalChanges() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.save() }
        }
    }

    // MARK: Folder

    func openFolder(_ url: URL) {
        save()
        rootURL = url
        currentURL = nil
        loading = true
        text = ""
        loading = false
        selection = nil
        var recents = recentFolders.map(\.path).filter { $0 != url.path }
        recents.insert(url.path, at: 0)
        recentData = (try? JSONEncoder().encode(Array(recents.prefix(8)))) ?? Data()
        refresh()
    }

    func closeFolder() {
        save()
        rootURL = nil
        tree = []
        selection = nil
        currentURL = nil
        loading = true; text = ""; loading = false
    }

    func refresh() {
        guard let root = rootURL else { return }
        tree = Self.scan(root)
    }

    private static func scan(_ dir: URL) -> [FileNode] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey],
                                                      options: [.skipsHiddenFiles]) else { return [] }
        var folders: [FileNode] = []
        var files: [FileNode] = []
        for url in items {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDir {
                guard !ignoredFolders.contains(url.lastPathComponent) else { continue }
                let children = scan(url)
                if !children.isEmpty { folders.append(FileNode(url: url, isDirectory: true, children: children)) }
            } else if markdownExtensions.contains(url.pathExtension.lowercased()) {
                files.append(FileNode(url: url, isDirectory: false))
            }
        }
        let sort: (FileNode, FileNode) -> Bool = { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return folders.sorted(by: sort) + files.sorted(by: sort)
    }

    // MARK: Files

    func openFile(_ url: URL) {
        let url = url.standardizedFileURL
        if let root = rootURL, url.path.hasPrefix(root.path + "/") {
            selection = url
        } else {
            openFolder(url.deletingLastPathComponent())
            selection = url
        }
    }

    private func open(_ url: URL) {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else { return }
        save()
        do {
            let contents = try String(contentsOf: url, encoding: .utf8)
            loading = true
            currentURL = url
            text = contents
            loading = false
            isDirty = false
            loadedModDate = modDate(url)
            lastFile = url.path
        } catch {
            errorMessage = "Couldn't open \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }

    private func markDirty() {
        guard currentURL != nil else { return }
        isDirty = true
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    func save() {
        saveTask?.cancel()
        guard isDirty, let url = currentURL else { return }
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            isDirty = false
            loadedModDate = modDate(url)
        } catch {
            errorMessage = "Couldn't save \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }

    private func modDate(_ url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    /// Reload the open file if it changed on disk (e.g. edited by git or another tool) and we have no pending edits.
    func checkForExternalChanges() {
        refresh()
        guard let url = currentURL else { return }
        guard FileManager.default.fileExists(atPath: url.path) else {
            currentURL = nil; selection = nil
            loading = true; text = ""; loading = false
            return
        }
        if !isDirty, let d = modDate(url), d != loadedModDate,
           let contents = try? String(contentsOf: url, encoding: .utf8) {
            loading = true; text = contents; loading = false
            loadedModDate = d
        }
    }

    func folderForNewItem(near node: FileNode? = nil) -> URL? {
        if let node { return node.isDirectory ? node.url : node.url.deletingLastPathComponent() }
        if let current = currentURL { return current.deletingLastPathComponent() }
        return rootURL
    }

    private func uniqueURL(in folder: URL, base: String, ext: String?) -> URL {
        var n = 1
        func make() -> URL {
            let name = n == 1 ? base : "\(base) \(n)"
            return ext.map { folder.appendingPathComponent(name).appendingPathExtension($0) } ?? folder.appendingPathComponent(name)
        }
        var url = make()
        while FileManager.default.fileExists(atPath: url.path) { n += 1; url = make() }
        return url
    }

    @discardableResult
    func newFile(in folder: URL? = nil) -> URL? {
        guard let folder = folder ?? folderForNewItem() else { return nil }
        let url = uniqueURL(in: folder, base: "Untitled", ext: "md")
        do {
            try "".write(to: url, atomically: true, encoding: .utf8)
            refresh()
            selection = url
            return url
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func newFolder(in folder: URL? = nil) {
        guard let folder = folder ?? folderForNewItem() else { return }
        let url = uniqueURL(in: folder, base: "New Folder", ext: nil)
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            // Empty folders are hidden from the tree, so seed it with a note.
            let note = url.appendingPathComponent("Untitled.md")
            try "".write(to: note, atomically: true, encoding: .utf8)
            refresh()
            selection = note
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rename(_ node: FileNode, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("/") else { return }
        let ext = node.url.pathExtension
        var dest = node.url.deletingLastPathComponent().appendingPathComponent(trimmed)
        if !node.isDirectory && (trimmed as NSString).pathExtension.isEmpty { dest.appendPathExtension(ext) }
        guard dest != node.url else { return }
        save()
        do {
            try FileManager.default.moveItem(at: node.url, to: dest)
            if let current = currentURL, current.path.hasPrefix(node.url.path) {
                let newCurrent = URL(fileURLWithPath: dest.path + current.path.dropFirst(node.url.path.count))
                currentURL = newCurrent
                selection = newCurrent
            }
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func moveToTrash(_ node: FileNode) {
        if let current = currentURL, current.path.hasPrefix(node.url.path) {
            save()
            currentURL = nil; selection = nil
            loading = true; text = ""; loading = false
        }
        do {
            try FileManager.default.trashItem(at: node.url, resultingItemURL: nil)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Handles ⌘-click on a link: web links go to the browser, relative Markdown links open in the editor.
    func followLink(_ link: String) {
        let trimmed = link.trimmingCharacters(in: .whitespaces).components(separatedBy: " ").first ?? link
        if let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty {
            NSWorkspace.shared.open(url)
            return
        }
        guard let base = currentURL?.deletingLastPathComponent() else { return }
        let path = (trimmed.removingPercentEncoding ?? trimmed).components(separatedBy: "#").first ?? trimmed
        guard !path.isEmpty else { return }
        let target = URL(fileURLWithPath: path, relativeTo: base).standardizedFileURL
        if Self.markdownExtensions.contains(target.pathExtension.lowercased()),
           FileManager.default.fileExists(atPath: target.path) {
            openFile(target)
        } else if FileManager.default.fileExists(atPath: target.path) {
            NSWorkspace.shared.open(target)
        }
    }

    // MARK: Panels

    func showOpenFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Open Folder"
        panel.message = "Choose a folder of Markdown files"
        if panel.runModal() == .OK, let url = panel.url { openFolder(url) }
    }

    func showOpenFilePanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = Self.markdownExtensions.compactMap { UTType(filenameExtension: $0) }
        if panel.runModal() == .OK, let url = panel.url { openFile(url) }
    }

    // MARK: Stats

    var stats: (words: Int, characters: Int, minutes: Int) {
        var words = 0
        text.enumerateSubstrings(in: text.startIndex..., options: [.byWords, .substringNotRequired]) { _, _, _, _ in words += 1 }
        return (words, text.count, max(1, Int((Double(words) / 230).rounded(.up))))
    }
}

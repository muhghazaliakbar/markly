import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var workspace: Workspace?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        AppTheme(rawValue: UserDefaults.standard.string(forKey: Pref.theme) ?? "")?.apply(animated: false)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        Task { @MainActor in
            for url in urls {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    workspace?.addFolder(url)
                } else {
                    workspace?.openFile(url)
                }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct MarklyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var workspace = Workspace()

    var body: some Scene {
        Window("Markly", id: "main") {
            ContentView()
                .environmentObject(workspace)
                .frame(minWidth: 640, minHeight: 420)
                .onAppear { delegate.workspace = workspace }
        }
        .defaultSize(width: 1240, height: 800)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands { MarklyCommands(workspace: workspace) }

        Settings {
            AppSettingsView()
        }
    }
}

private func send(_ selector: Selector) {
    NSApp.sendAction(selector, to: nil, from: nil)
}

struct MarklyCommands: Commands {
    @ObservedObject var workspace: Workspace
    @AppStorage(Pref.fontSize) private var fontSize = 16.0
    @AppStorage(Pref.accent) private var accent = AccentChoice.system

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New File") { workspace.newFile() }
                .keyboardShortcut("n")
                .disabled(!workspace.hasFolders)
            Button("New Folder") { workspace.newFolder() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(!workspace.hasFolders)
            Divider()
            Button("Add Folder…") { workspace.showOpenFolderPanel() }
                .keyboardShortcut("o")
            Button("Open File…") { workspace.showOpenFilePanel() }
                .keyboardShortcut("o", modifiers: [.command, .shift])
        }
        CommandGroup(replacing: .saveItem) {
            Button("Save") { workspace.save() }
                .keyboardShortcut("s")
            Button("Reveal in Finder") { if let u = workspace.currentURL { workspace.revealInFinder(u) } }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(workspace.currentURL == nil)
        }
        CommandGroup(after: .importExport) {
            Button("Export as HTML…") { Exporter.exportHTML(markdown: workspace.text, url: workspace.currentURL, accent: accent.nsColor) }
                .disabled(workspace.currentURL == nil)
            Button("Export as PDF…") { Exporter.exportPDF(markdown: workspace.text, url: workspace.currentURL, accent: accent.nsColor) }
                .disabled(workspace.currentURL == nil)
        }
        CommandGroup(replacing: .printItem) {
            Button("Print…") { Exporter.print(markdown: workspace.text, url: workspace.currentURL, accent: accent.nsColor) }
                .keyboardShortcut("p")
                .disabled(workspace.currentURL == nil)
        }
        TextEditingCommands()

        CommandMenu("Format") {
            Button("Bold") { send(#selector(MarkdownTextView.toggleBold(_:))) }.keyboardShortcut("b")
            Button("Italic") { send(#selector(MarkdownTextView.toggleItalic(_:))) }.keyboardShortcut("i")
            Button("Strikethrough") { send(#selector(MarkdownTextView.toggleStrikethrough(_:))) }.keyboardShortcut("x", modifiers: [.command, .shift])
            Button("Highlight") { send(#selector(MarkdownTextView.toggleHighlight(_:))) }.keyboardShortcut("h", modifiers: [.command, .shift])
            Button("Inline Code") { send(#selector(MarkdownTextView.toggleInlineCode(_:))) }.keyboardShortcut("e")
            Button("Link") { send(#selector(MarkdownTextView.insertLink(_:))) }.keyboardShortcut("k")
            Divider()
            Button("Heading 1") { send(#selector(MarkdownTextView.heading1(_:))) }.keyboardShortcut("1", modifiers: [.command, .option])
            Button("Heading 2") { send(#selector(MarkdownTextView.heading2(_:))) }.keyboardShortcut("2", modifiers: [.command, .option])
            Button("Heading 3") { send(#selector(MarkdownTextView.heading3(_:))) }.keyboardShortcut("3", modifiers: [.command, .option])
            Button("Heading 4") { send(#selector(MarkdownTextView.heading4(_:))) }.keyboardShortcut("4", modifiers: [.command, .option])
            Button("Body Text") { send(#selector(MarkdownTextView.bodyText(_:))) }.keyboardShortcut("0", modifiers: [.command, .option])
            Divider()
            Button("Bulleted List") { send(#selector(MarkdownTextView.toggleBulletList(_:))) }.keyboardShortcut("8", modifiers: [.command, .shift])
            Button("Numbered List") { send(#selector(MarkdownTextView.toggleNumberedList(_:))) }.keyboardShortcut("7", modifiers: [.command, .shift])
            Button("Task List") { send(#selector(MarkdownTextView.toggleTaskList(_:))) }.keyboardShortcut("t", modifiers: [.command, .shift])
            Button("Quote") { send(#selector(MarkdownTextView.toggleQuote(_:))) }.keyboardShortcut("'", modifiers: [.command])
            Divider()
            Button("Code Block") { send(#selector(MarkdownTextView.insertCodeBlock(_:))) }.keyboardShortcut("c", modifiers: [.command, .option])
            Button("Table") { send(#selector(MarkdownTextView.insertTable(_:))) }.keyboardShortcut("t", modifiers: [.command, .option])
            Button("Horizontal Rule") { send(#selector(MarkdownTextView.insertRule(_:))) }.keyboardShortcut("-", modifiers: [.command, .option])
        }

        CommandGroup(after: .sidebar) {
            Toggle("Show Preview", isOn: $workspace.showPreview.animation(GlassStyle.fade))
                .keyboardShortcut("p", modifiers: [.command, .option])
            Toggle("Focus Mode", isOn: $workspace.focusMode.animation(GlassStyle.spring))
                .keyboardShortcut("f", modifiers: [.command, .shift])
            Toggle("Editor Settings", isOn: $workspace.showInspector)
                .keyboardShortcut("i", modifiers: [.command, .option])
            Divider()
            Button("Bigger Text") { fontSize = min(28, fontSize + 1) }.keyboardShortcut("+")
            Button("Smaller Text") { fontSize = max(11, fontSize - 1) }.keyboardShortcut("-")
            Button("Actual Size") { fontSize = 16 }.keyboardShortcut("0")
            Divider()
        }

        CommandMenu("Go") {
            let files = workspace.quickFiles
            if files.isEmpty {
                Text("No notes")
            }
            ForEach(Array(files.enumerated()), id: \.element) { i, url in
                Button(url.deletingPathExtension().lastPathComponent) { workspace.selection = url }
                    .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: .command)
            }
        }
    }
}

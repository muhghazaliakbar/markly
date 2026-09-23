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
    @AppStorage(Pref.accentCustom) private var accentCustom = ""
    @AppStorage(Pref.typewriter) private var typewriter = false
    @AppStorage(Pref.focusParagraph) private var focusParagraph = false
    @AppStorage(Pref.smartLists) private var smartLists = true
    @AppStorage(Pref.selectionToolbar) private var selectionToolbar = true
    @AppStorage(Pref.animateTransitions) private var animateTransitions = true
    @AppStorage(Pref.previewNetwork) private var previewNetwork = true
    @AppStorage(Pref.remoteImages) private var remoteImages = true

    @State private var columns = NavigationSplitViewVisibility.all
    /// The panel's frame in window (global) coordinates, so clicks outside it can close it.
    @State private var panelFrame: CGRect = .zero
    /// The panel stays mounted while it animates out, so closing plays the opening animation in reverse
    /// (removal transitions can drop AppKit-backed views like the blur without animating them).
    @State private var panelMounted = false
    @State private var panelVisible = false

    private var style: EditorStyle {
        EditorStyle(font: font, fontSize: fontSize, lineSpacing: lineSpacing, maxWidth: editorWidth,
                    syntax: syntax, accent: accent, spellCheck: spellCheck, imagePreview: imagePreview,
                    accentHex: accent == .custom ? accentCustom : "", typewriter: typewriter,
                    focusParagraph: focusParagraph, smartLists: smartLists, selectionToolbar: selectionToolbar)
    }

    var body: some View {
        Group {
            if !workspace.hasFolders {
                WelcomeView()
            } else {
                NavigationSplitView(columnVisibility: $columns) {
                    SidebarView(git: git)
                        .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 420)
                        .background { BehindWindowBlur().ignoresSafeArea() }
                } detail: {
                    detail
                }
            }
        }
        .tint(accent.color)
        .onAppear {
            panelMounted = showPanel
            panelVisible = showPanel
        }
        .onChange(of: showPanel) { _, show in
            if show {
                panelMounted = true
                // Next turn, so the panel is laid out off-screen before it slides in.
                DispatchQueue.main.async {
                    withAnimation(GlassStyle.spring) { panelVisible = true }
                }
            } else {
                withAnimation(GlassStyle.spring) {
                    panelVisible = false
                } completion: {
                    if !showPanel { panelMounted = false }
                }
            }
        }
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
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .bottom) {
                Group {
                    if let url = workspace.currentURL {
                        HSplitView {
                            EditorView(text: Binding(get: { workspace.text }, set: { workspace.text = $0 }),
                                       style: style, baseURL: url.deletingLastPathComponent(),
                                       revision: workspace.revision,
                                       documentID: url, animateSwitch: animateTransitions,
                                       overlayTrailingInset: showPanel ? 312 : 0,
                                       onOpenLink: { workspace.followLink($0) })
                                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
                            if workspace.showPreview {
                                LivePreview(live: workspace.live, fileURL: url, accent: accent.nsColor,
                                            privacyKey: "\(previewNetwork)\(remoteImages)\(accentCustom)")
                                    .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .transition(.opacity)
                    } else {
                        EmptyEditor()
                            .transition(.opacity)
                    }
                }
                // Only the empty state ↔ editor fades here; file-to-file swaps are animated by the editor itself.
                .animation(GlassStyle.fade, value: workspace.currentURL == nil)

                if showStatusBar && !workspace.focusMode && workspace.currentURL != nil {
                    StatusPill(live: workspace.live)
                        .padding(.bottom, 14)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // The panel floats above the editor and never changes its layout. Only the column right
            // behind it is frosted, so the rest of the page stays sharp and editable while you tweak it.
            if panelMounted {
                EditorSettingsPanel()
                    .frame(maxHeight: .infinity, alignment: .top)
                    .background(alignment: .trailing) { PanelFrost() }
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { panelFrame = $0 }
                    .offset(x: panelVisible ? 0 : 340)
                    .opacity(panelVisible ? 1 : 0)
                    .allowsHitTesting(panelVisible)
                    .accessibilityHidden(!panelVisible)
            }

            if workspace.focusMode {
                Button { withAnimation(GlassStyle.spring) { workspace.focusMode = false } } label: {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .frame(width: 34, height: 34).contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: Circle())
                .padding(16)
                .help("Exit Focus Mode (⇧⌘F)")
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .background {
            // Clicking the editor or preview outside the panel closes it; the click still reaches the editor.
            ClickOutsideToClose(isActive: showPanel, excluded: panelFrame) {
                withAnimation(GlassStyle.spring) { workspace.showInspector = false }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .environment(\.workspaceClose) { withAnimation(GlassStyle.spring) { workspace.showInspector = false } }
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
            Toggle(isOn: $workspace.showPreview.animation(GlassStyle.fade)) { Label("Preview", systemImage: "doc.richtext") }
                .help("Toggle Preview (⌥⌘P)")
                .disabled(workspace.currentURL == nil)
            Button { withAnimation(GlassStyle.spring) { workspace.focusMode.toggle() } } label: { Label("Focus", systemImage: "arrow.up.left.and.arrow.down.right") }
                .help("Focus Mode (⇧⌘F)")
                .disabled(workspace.currentURL == nil)
        }
        ToolbarSpacer(.fixed, placement: .primaryAction)
        ToolbarItem(placement: .primaryAction) {
            Toggle(isOn: $workspace.showInspector.animation(GlassStyle.spring)) {
                Label("Editor Settings", systemImage: "textformat.size")
            }
            .help("Editor Settings (⌥⌘I)")
        }
    }
}

/// Progressive blur behind the appearance panel, exactly as wide as the panel: strongest at the window's
/// right edge, fading to clear at the panel's left edge. Esc closes the panel.
struct PanelFrost: View {
    @Environment(\.workspaceClose) private var close

    var body: some View {
        ProgressiveBlur(radius: 18)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .background {
                Button("") { close() }.keyboardShortcut(.cancelAction).hidden()
            }
    }
}

/// Watches left clicks in the window without consuming them. Fires `onClose` for clicks inside this view's
/// area (the detail pane) that land outside `excluded` and below the toolbar.
struct ClickOutsideToClose: NSViewRepresentable {
    var isActive: Bool
    var excluded: CGRect
    var onClose: () -> Void

    func makeNSView(context: Context) -> ClickMonitorView { ClickMonitorView() }

    func updateNSView(_ view: ClickMonitorView, context: Context) {
        view.isActive = isActive
        view.excluded = excluded
        view.onClose = onClose
    }
}

final class ClickMonitorView: NSView {
    var isActive = false
    var excluded: CGRect = .zero
    var onClose: () -> Void = {}
    private var monitor: Any?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.handle(event)
            return event  // never swallow the click
        }
    }

    private func handle(_ event: NSEvent) {
        guard let window, event.window === window, shouldClose(forClickAt: event.locationInWindow) else { return }
        let close = onClose
        DispatchQueue.main.async { close() }
    }

    /// - Parameter p: click location in window coordinates (bottom-left origin).
    func shouldClose(forClickAt p: NSPoint) -> Bool {
        guard isActive, let window else { return false }
        // Ignore the titlebar/toolbar (the panel's own toggle lives there) and the file sidebar.
        guard window.contentLayoutRect.contains(p), bounds.contains(convert(p, from: nil)) else { return false }
        // SwiftUI's global space is top-left origin in the window's content view.
        let height = window.contentView?.bounds.height ?? window.frame.height
        return !excluded.contains(CGPoint(x: p.x, y: height - p.y))
    }
}

private struct WorkspaceCloseKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var workspaceClose: () -> Void {
        get { self[WorkspaceCloseKey.self] }
        set { self[WorkspaceCloseKey.self] = newValue }
    }
}

/// Observes only the throttled live document, so the rest of the window doesn't re-render while typing.
struct LivePreview: View {
    @ObservedObject var live: LiveDocument
    var fileURL: URL
    var accent: NSColor
    /// Reloads the page when privacy settings (or a custom accent) change.
    var privacyKey: String = ""

    var body: some View {
        PreviewView(markdown: live.text, fileURL: fileURL, accent: accent, reloadKey: privacyKey,
                    animateSwitch: Pref.bool(Pref.animateTransitions, default: true))
    }
}

struct StatusPill: View {
    @ObservedObject var live: LiveDocument

    var body: some View {
        let s = live.stats
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
        .animation(GlassStyle.snappy, value: s)
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

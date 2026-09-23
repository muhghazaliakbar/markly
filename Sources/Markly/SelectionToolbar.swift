import AppKit
import SwiftUI

/// Formatting offered by the floating bar that appears over selected text (like Medium's inline editor).
enum FormatAction: String, CaseIterable, Identifiable {
    case bold, italic, strikethrough, highlight, code, link, heading1, heading2, quote
    var id: Self { self }

    var symbol: String {
        switch self {
        case .bold: "bold"
        case .italic: "italic"
        case .strikethrough: "strikethrough"
        case .highlight: "highlighter"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .link: "link"
        case .heading1: "textformat.size.larger"
        case .heading2: "textformat.size.smaller"
        case .quote: "text.quote"
        }
    }

    var title: String {
        switch self {
        case .bold: "Bold"
        case .italic: "Italic"
        case .strikethrough: "Strikethrough"
        case .highlight: "Highlight"
        case .code: "Inline Code"
        case .link: "Link"
        case .heading1: "Large Heading"
        case .heading2: "Small Heading"
        case .quote: "Quote"
        }
    }

    var shortcut: String {
        switch self {
        case .bold: "⌘B"
        case .italic: "⌘I"
        case .strikethrough: "⇧⌘X"
        case .highlight: "⇧⌘H"
        case .code: "⌘E"
        case .link: "⌘K"
        case .heading1: "⌥⌘1"
        case .heading2: "⌥⌘2"
        case .quote: "⌘'"
        }
    }

    /// Inline formats come first, then block formats after a divider.
    static let inline: [FormatAction] = [.bold, .italic, .strikethrough, .highlight, .code, .link]
    static let block: [FormatAction] = [.heading1, .heading2, .quote]
}

@MainActor
final class SelectionToolbarModel: ObservableObject {
    @Published var visible = false
    @Published var active: Set<FormatAction> = []
    @Published var editingLink = false
    @Published var linkURL = ""

    weak var textView: MarkdownTextView?
    /// Called when the bar changes size (e.g. the link field opens), so it can be re-positioned.
    var onResize: () -> Void = {}

    func perform(_ action: FormatAction) {
        guard let tv = textView else { return }
        switch action {
        case .bold: tv.toggleBold(nil)
        case .italic: tv.toggleItalic(nil)
        case .strikethrough: tv.toggleStrikethrough(nil)
        case .highlight: tv.toggleHighlight(nil)
        case .code: tv.toggleInlineCode(nil)
        case .heading1: tv.heading1(nil)
        case .heading2: tv.heading2(nil)
        case .quote: tv.toggleQuote(nil)
        case .link:
            if tv.removeLink() { break }
            beginLink()
            return
        }
        refresh()
        tv.window?.makeFirstResponder(tv)
    }

    func refresh() {
        active = textView?.formatState() ?? []
    }

    func beginLink() {
        let clip = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let looksLikeURL = clip.hasPrefix("http://") || clip.hasPrefix("https://") || clip.hasPrefix("mailto:")
        linkURL = looksLikeURL && !clip.contains(" ") ? clip : ""
        withAnimation(GlassStyle.spring) { editingLink = true }
        onResize()
    }

    func commitLink() {
        textView?.applyLink(linkURL)
        endLink()
        refresh()
    }

    func endLink() {
        withAnimation(GlassStyle.spring) { editingLink = false }
        onResize()
        if let tv = textView { tv.window?.makeFirstResponder(tv) }
    }
}

/// The bar itself: one Liquid Glass capsule of standard toggle buttons. Appearing and disappearing use the
/// system's glass materialize transition; switching to the link field is a native glass morph.
struct SelectionToolbarView: View {
    @ObservedObject var model: SelectionToolbarModel
    @Namespace private var glass
    @FocusState private var linkFocused: Bool

    var body: some View {
        GlassEffectContainer {
            if model.visible {
                Group {
                    if model.editingLink { linkField } else { buttons }
                }
                .glassEffect(.regular.interactive(), in: Capsule())
                .glassEffectID(model.editingLink ? "link" : "buttons", in: glass)
                .glassEffectTransition(.materialize)
            }
        }
        .padding(8)  // room for the glass shadow
        .fixedSize()
    }

    private var buttons: some View {
        HStack(spacing: 2) {
            ForEach(FormatAction.inline) { toggle($0) }
            Divider().frame(height: 18).padding(.horizontal, 4)
            ForEach(FormatAction.block) { toggle($0) }
        }
        .toggleStyle(.button)
        .buttonStyle(.borderless)
        .controlSize(.large)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }

    private func toggle(_ action: FormatAction) -> some View {
        Toggle(isOn: Binding(get: { model.active.contains(action) }, set: { _ in model.perform(action) })) {
            Label(action.title, systemImage: action.symbol)
                .labelStyle(.iconOnly)
                .frame(width: 22, height: 22)
        }
        .help("\(action.title) (\(action.shortcut))")
        .accessibilityLabel(action.title)
    }

    private var linkField: some View {
        HStack(spacing: 6) {
            Image(systemName: "link").foregroundStyle(.secondary)
            TextField("Paste or type a link", text: $model.linkURL)
                .textFieldStyle(.plain)
                .frame(width: 240)
                .focused($linkFocused)
                .onSubmit { model.commitLink() }
                .onExitCommand { model.endLink() }
            Button { model.commitLink() } label: {
                Label("Apply Link", systemImage: "return").labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .disabled(model.linkURL.trimmingCharacters(in: .whitespaces).isEmpty)
            .keyboardShortcut(.defaultAction)
            Button { model.endLink() } label: {
                Label("Cancel", systemImage: "xmark").labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
        }
        .controlSize(.large)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .onAppear { linkFocused = true }
    }
}

/// Hosting view that only takes clicks where the bar actually is.
final class SelectionToolbarHostingView: NSHostingView<SelectionToolbarView> {
    var isActive = false
    override func hitTest(_ point: NSPoint) -> NSView? {
        isActive ? super.hitTest(point) : nil
    }
}

/// Shows, positions and hides the format bar for one editor.
@MainActor
final class SelectionToolbarController {
    let model = SelectionToolbarModel()
    private let host: SelectionToolbarHostingView
    private weak var container: NSView?
    private var pending: DispatchWorkItem?
    private var hideWork: DispatchWorkItem?
    var enabled = true { didSet { if !enabled { hide() } } }

    init(container: NSView, textView: MarkdownTextView) {
        self.container = container
        model.textView = textView
        host = SelectionToolbarHostingView(rootView: SelectionToolbarView(model: model))
        host.sizingOptions = [.intrinsicContentSize]
        host.isHidden = true
        container.addSubview(host)
        model.onResize = { [weak self] in
            DispatchQueue.main.async { self?.reposition() }
        }
    }

    /// Selection changed: wait until the mouse is released (and keyboard selection pauses) before showing.
    func selectionChanged() {
        pending?.cancel()
        guard enabled, let tv = model.textView else { return }
        if tv.selectedRange().length == 0 || isBlankSelection(tv) {
            hide()
            return
        }
        if model.visible && !model.editingLink {
            // Already showing: follow the selection immediately.
            model.refresh()
            reposition()
        }
        let work = DispatchWorkItem { [weak self] in self?.showIfReady() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
    }

    private func showIfReady() {
        guard let tv = model.textView, tv.selectedRange().length > 0, !isBlankSelection(tv) else { return }
        if NSEvent.pressedMouseButtons != 0 {
            let work = DispatchWorkItem { [weak self] in self?.showIfReady() }
            pending = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
            return
        }
        guard tv.window?.firstResponder === tv else { return }
        show()
    }

    private func isBlankSelection(_ tv: NSTextView) -> Bool {
        (tv.string as NSString).substring(with: tv.selectedRange()).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func show() {
        hideWork?.cancel()
        model.refresh()
        host.isHidden = false
        host.isActive = true
        reposition()
        if !model.visible {
            withAnimation(GlassStyle.spring) { model.visible = true }
        }
    }

    func hide() {
        pending?.cancel()
        guard model.visible || !host.isHidden else { return }
        host.isActive = false
        withAnimation(GlassStyle.spring) {
            model.visible = false
            model.editingLink = false
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.model.visible else { return }
            self.host.isHidden = true
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    /// Centres the bar above the first line of the selection, or below the selection when there's no room.
    func reposition() {
        guard model.visible || host.isActive, let container, let tv = model.textView,
              let window = tv.window, let scroll = tv.enclosingScrollView else { return }
        let sel = tv.selectedRange()
        guard sel.length > 0 else { hide(); return }
        let size = host.fittingSize
        let firstScreen = tv.firstRect(forCharacterRange: NSRange(location: sel.location, length: min(sel.length, 1)), actualRange: nil)
        let lastScreen = tv.firstRect(forCharacterRange: NSRange(location: NSMaxRange(sel) - 1, length: 1), actualRange: nil)
        let wholeFirst = tv.firstRect(forCharacterRange: sel, actualRange: nil)
        func toContainer(_ r: NSRect) -> NSRect { container.convert(window.convertFromScreen(r), from: nil) }
        let first = toContainer(wholeFirst.isEmpty ? firstScreen : wholeFirst)
        let last = toContainer(lastScreen)

        let visibleTop = scroll.contentInsets.top + 4
        let visible = container.bounds.insetBy(dx: 0, dy: 0)
        var y = first.minY - size.height - 2        // container is flipped: minY is the top edge
        if y < visibleTop { y = last.maxY + 6 }      // no room above: go below
        var x = first.midX - size.width / 2
        x = min(max(x, 8), visible.width - size.width - 8)
        // Hide while the selection is scrolled out of view.
        if first.maxY < visibleTop || first.minY > visible.maxY {
            host.frame.origin = NSPoint(x: -10_000, y: -10_000)
            return
        }
        host.frame = NSRect(x: x.rounded(), y: y.rounded(), width: size.width, height: size.height)
    }
}

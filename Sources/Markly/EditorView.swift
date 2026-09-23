import AppKit
import SwiftUI

struct EditorView: NSViewRepresentable {
    @Binding var text: String
    var style: EditorStyle
    var baseURL: URL?
    /// Bumped when the text is replaced from outside the editor.
    var revision: Int = 0
    var blurRadius: CGFloat = 0
    var onOpenLink: (String) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let storage = NSTextStorage()
        let layout = MarkdownLayoutManager()
        // Lay out only what's on screen; keeps long notes fast to open, scroll and resize.
        layout.allowsNonContiguousLayout = true
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layout.addTextContainer(container)

        let textView = MarkdownTextView(frame: .zero, textContainer: container)
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.onOpenLink = { onOpenLink($0) }

        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = true
        scroll.backgroundColor = .textBackgroundColor
        scroll.contentView.postsBoundsChangedNotifications = false

        let coordinator = context.coordinator
        coordinator.textView = textView
        coordinator.highlighter.imageProvider = { [weak coordinator] src in
            ImageStore.shared.image(for: src, relativeTo: coordinator?.parent.baseURL)
        }
        textView.onColumnWidthChange = { [weak coordinator] width in
            coordinator?.columnWidthChanged(width)
        }
        coordinator.apply(style: style)
        textView.string = text
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        coordinator.revision = revision
        coordinator.rehighlight()

        DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let textView = coordinator.textView else { return }
        textView.onOpenLink = { onOpenLink($0) }
        LayerBlur.set(blurRadius, on: scroll)
        if coordinator.style != style {
            coordinator.scheduleStyle(style)
        }
        if coordinator.revision != revision {
            coordinator.revision = revision
            if textView.string != text {
                let selection = textView.selectedRange()
                textView.string = text
                let len = (text as NSString).length
                textView.setSelectedRange(NSRange(location: min(selection.location, len), length: 0))
                coordinator.rehighlight()
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorView
        weak var textView: MarkdownTextView?
        let highlighter = MarkdownHighlighter()
        var style = EditorStyle()
        private var lastActive: NSRange?
        private var highlighting = false

        private var imageObserver: NSObjectProtocol?
        private var pendingWidthWork: DispatchWorkItem?
        var revision = 0
        private var pendingStyle: EditorStyle?
        /// Lines touched by the edit in progress, and whether it added or removed fence markers.
        private var editedRange: NSRange?
        private var editTouchesBlocks = false

        init(_ parent: EditorView) {
            self.parent = parent
            super.init()
            imageObserver = NotificationCenter.default.addObserver(forName: .marklyImageLoaded, object: nil, queue: .main) { [weak self] _ in
                self?.rehighlight()
            }
        }

        deinit {
            if let imageObserver { NotificationCenter.default.removeObserver(imageObserver) }
        }

        private var hasImages: Bool { textView?.string.contains("![") ?? false }

        func columnWidthChanged(_ width: CGFloat) {
            highlighter.columnWidth = width
            guard style.imagePreview != .off, hasImages else { return }
            pendingWidthWork?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.rehighlight() }
            pendingWidthWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
        }

        /// Slider drags can change the style many times per frame; apply once per run-loop turn.
        func scheduleStyle(_ style: EditorStyle) {
            let first = pendingStyle == nil
            pendingStyle = style
            guard first else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, let style = self.pendingStyle else { return }
                self.pendingStyle = nil
                self.apply(style: style)
                self.rehighlight()
            }
        }

        func apply(style: EditorStyle) {
            self.style = style
            highlighter.style = style
            guard let tv = textView else { return }
            tv.maxContentWidth = style.maxWidth
            tv.insertionPointColor = style.accent.nsColor
            tv.isContinuousSpellCheckingEnabled = style.spellCheck
            tv.typingAttributes = highlighter.typingAttributes
            tv.selectedTextAttributes = [.backgroundColor: Palette.accentTint(style.accent.nsColor, alpha: 0.25)]
            (tv.layoutManager as? MarkdownLayoutManager)?.accent = style.accent.nsColor
        }

        private func activeLines(_ tv: NSTextView) -> NSRange {
            let ns = tv.string as NSString
            let sel = tv.selectedRange()
            guard ns.length > 0 else { return NSRange(location: 0, length: 0) }
            return ns.lineRange(for: NSRange(location: min(sel.location, ns.length), length: min(sel.length, ns.length - min(sel.location, ns.length))))
        }

        /// Restyles the whole document, or just `limits` (plus the old and new caret lines).
        func rehighlight(limits: [NSRange]? = nil) {
            guard let tv = textView, let storage = tv.textStorage, !highlighting else { return }
            highlighting = true
            defer { highlighting = false }
            let active = activeLines(tv)
            let previous = lastActive
            lastActive = active
            var ranges = limits
            if ranges != nil {
                ranges?.append(active)
                if let previous, NSMaxRange(previous) <= storage.length { ranges?.append(previous) }
            }
            highlighter.highlight(storage, active: active, limits: ranges)
            tv.typingAttributes = highlighter.typingAttributes
        }

        /// Don't flag spelling inside collapsed (hidden) Markdown syntax.
        func textView(_ textView: NSTextView, shouldSetSpellingState value: Int, range: NSRange) -> Int {
            guard value != 0, let storage = textView.textStorage, range.location < storage.length,
                  let font = storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont,
                  font.pointSize < 1 else { return value }
            return 0
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString: String?) -> Bool {
            let ns = textView.string as NSString
            let replaced = range.length > 0 && NSMaxRange(range) <= ns.length ? ns.substring(with: range) : ""
            if MarkdownHighlighter.affectsBlocks(replaced) || MarkdownHighlighter.affectsBlocks(replacementString ?? "") {
                editTouchesBlocks = true
            }
            let inserted = NSRange(location: range.location, length: (replacementString as NSString?)?.length ?? 0)
            editedRange = editedRange.map { NSUnionRange($0, inserted) } ?? inserted
            return true
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            let ns = tv.string as NSString
            defer { editedRange = nil; editTouchesBlocks = false }
            if let edit = editedRange, !editTouchesBlocks, NSMaxRange(edit) <= ns.length {
                // One extra character so the line created by a Return is restyled too.
                let lines = ns.lineRange(for: NSRange(location: edit.location, length: min(edit.length + 1, ns.length - edit.location)))
                if MarkdownHighlighter.affectsBlocks(ns.substring(with: lines)) {
                    rehighlight()
                } else {
                    rehighlight(limits: [lines])
                }
            } else {
                rehighlight()
            }
            parent.text = tv.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard style.syntax == .focused, let tv = textView, !highlighting else { return }
            // Only restyle when the caret moves to a different line.
            let active = activeLines(tv)
            guard active != lastActive else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, let tv = self.textView, self.activeLines(tv) != self.lastActive else { return }
                self.rehighlight(limits: [])
            }
        }
    }
}

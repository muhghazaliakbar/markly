import AppKit
import SwiftUI

struct EditorView: NSViewRepresentable {
    @Binding var text: String
    var style: EditorStyle
    var onOpenLink: (String) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let storage = NSTextStorage()
        let layout = MarkdownLayoutManager()
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
        coordinator.apply(style: style)
        textView.string = text
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        coordinator.rehighlight()

        DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let textView = coordinator.textView else { return }
        textView.onOpenLink = { onOpenLink($0) }
        var needsHighlight = false
        if coordinator.style != style {
            coordinator.apply(style: style)
            needsHighlight = true
        }
        if textView.string != text {
            let selection = textView.selectedRange()
            textView.string = text
            let len = (text as NSString).length
            textView.setSelectedRange(NSRange(location: min(selection.location, len), length: 0))
            needsHighlight = true
        }
        if needsHighlight { coordinator.rehighlight() }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorView
        weak var textView: MarkdownTextView?
        let highlighter = MarkdownHighlighter()
        var style = EditorStyle()
        private var lastActive: NSRange?
        private var highlighting = false

        init(_ parent: EditorView) { self.parent = parent }

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

        func rehighlight() {
            guard let tv = textView, let storage = tv.textStorage, !highlighting else { return }
            highlighting = true
            defer { highlighting = false }
            let active = activeLines(tv)
            lastActive = active
            highlighter.highlight(storage, active: active)
            tv.typingAttributes = highlighter.typingAttributes
            tv.needsDisplay = true
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            rehighlight()
            parent.text = tv.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard style.syntax == .focused, let tv = textView, !highlighting else { return }
            // Only restyle when the caret moves to a different line.
            let active = activeLines(tv)
            guard active != lastActive else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, let tv = self.textView, self.activeLines(tv) != self.lastActive else { return }
                self.rehighlight()
            }
        }
    }
}

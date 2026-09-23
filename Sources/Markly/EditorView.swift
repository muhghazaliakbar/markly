import AppKit
import SwiftUI

struct EditorView: NSViewRepresentable {
    @Binding var text: String
    var style: EditorStyle
    var baseURL: URL?
    /// Bumped when the text is replaced from outside the editor.
    var revision: Int = 0
    /// The open file. The editor view stays alive across files; changing this swaps its content in place
    /// (with a transition) instead of rebuilding the view, which is what used to make the text jump.
    var documentID: URL? = nil
    var animateSwitch: Bool = true
    var onOpenLink: (String) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> EditorContainerView {
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
        let containerView = EditorContainerView(scrollView: scroll)

        let coordinator = context.coordinator
        coordinator.documentID = documentID
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
        return containerView
    }

    func updateNSView(_ container: EditorContainerView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let textView = coordinator.textView else { return }
        textView.onOpenLink = { onOpenLink($0) }
        if coordinator.style != style {
            coordinator.scheduleStyle(style)
        }
        if coordinator.documentID != documentID {
            coordinator.revision = revision
            coordinator.switchDocument(to: documentID, text: text, animated: animateSwitch)
        } else if coordinator.revision != revision {
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
        var documentID: URL?
        private var pendingStyle: EditorStyle?

        /// Per-file caret, scroll position and undo history, so returning to a note is seamless.
        private struct DocumentState { var selection: NSRange; var scroll: NSPoint }
        private var states: [URL: DocumentState] = [:]
        private var undoManagers: [URL: UndoManager] = [:]
        private let scratchUndo = UndoManager()

        func undoManager(for view: NSTextView) -> UndoManager? {
            guard let id = documentID else { return scratchUndo }
            if let existing = undoManagers[id] { return existing }
            let manager = UndoManager()
            undoManagers[id] = manager
            return manager
        }

        // MARK: Switching files

        func switchDocument(to id: URL?, text: String, animated: Bool) {
            guard let tv = textView, let scroll = tv.enclosingScrollView,
                  let container = scroll.superview as? EditorContainerView,
                  let lm = tv.layoutManager, let tc = tv.textContainer else { return }
            if let old = documentID {
                states[old] = DocumentState(selection: tv.selectedRange(), scroll: scroll.contentView.bounds.origin)
            }
            let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            let snapshot = animated && container.window != nil ? container.snapshot() : nil

            documentID = id
            editedRange = nil
            editTouchesBlocks = false
            lastActive = nil
            dimmedParagraph = nil

            // Build the new page completely before anything is shown: text, styling, layout, position.
            tv.string = text
            let length = (text as NSString).length
            let state = id.flatMap { states[$0] }
            let sel = state?.selection ?? NSRange(location: 0, length: 0)
            tv.setSelectedRange(NSRange(location: min(sel.location, length), length: min(sel.length, max(0, length - min(sel.location, length)))))
            rehighlight()
            var origin = state?.scroll ?? NSPoint(x: 0, y: -scroll.contentInsets.top)
            let maxY = max(-scroll.contentInsets.top, tv.frame.height - scroll.contentView.bounds.height)
            origin.y = min(max(origin.y, -scroll.contentInsets.top), maxY)
            lm.ensureLayout(forBoundingRect: NSRect(origin: origin, size: scroll.contentView.bounds.size), in: tc)
            scroll.contentView.scroll(to: origin)
            scroll.reflectScrolledClipView(scroll.contentView)
            container.layoutSubtreeIfNeeded()

            guard let snapshot else { return }
            container.play(from: snapshot, reduceMotion: reduceMotion)
        }
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
            tv.smartLists = style.smartLists
            tv.typewriter = style.typewriter
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
            updateFocusDim(force: true)
        }

        // MARK: Focus paragraph

        private var dimmedParagraph: NSRange?

        /// Dims everything except the paragraph holding the caret. Uses the layout manager's temporary
        /// attributes, so the text storage (and undo, and highlighting) is untouched.
        func updateFocusDim(force: Bool = false) {
            guard let tv = textView, let lm = tv.layoutManager else { return }
            let ns = tv.string as NSString
            let full = NSRange(location: 0, length: ns.length)
            guard style.focusParagraph, ns.length > 0 else {
                if dimmedParagraph != nil { lm.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full) }
                dimmedParagraph = nil
                return
            }
            let paragraph = Self.paragraphRange(in: ns, at: tv.selectedRange().location)
            guard force || paragraph != dimmedParagraph else { return }
            dimmedParagraph = paragraph
            lm.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full)
            let dim = NSColor.tertiaryLabelColor
            if paragraph.location > 0 {
                lm.addTemporaryAttribute(.foregroundColor, value: dim, forCharacterRange: NSRange(location: 0, length: paragraph.location))
            }
            let end = NSMaxRange(paragraph)
            if end < ns.length {
                lm.addTemporaryAttribute(.foregroundColor, value: dim, forCharacterRange: NSRange(location: end, length: ns.length - end))
            }
        }

        /// The run of non-blank lines around `location`.
        static func paragraphRange(in ns: NSString, at location: Int) -> NSRange {
            let loc = min(location, ns.length)
            func isBlank(_ r: NSRange) -> Bool {
                ns.substring(with: r).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            var start = ns.lineRange(for: NSRange(location: loc, length: 0))
            if isBlank(start) { return start }
            var end = start
            while start.location > 0 {
                let prev = ns.lineRange(for: NSRange(location: start.location - 1, length: 0))
                if isBlank(prev) { break }
                start = prev
            }
            while NSMaxRange(end) < ns.length {
                let next = ns.lineRange(for: NSRange(location: NSMaxRange(end), length: 0))
                if isBlank(next) { break }
                end = next
            }
            return NSRange(location: start.location, length: NSMaxRange(end) - start.location)
        }

        // MARK: Typewriter scrolling

        func centerCaret() {
            guard style.typewriter, let tv = textView, tv.selectedRange().length == 0,
                  NSEvent.pressedMouseButtons == 0,  // don't fight a mouse selection
                  let lm = tv.layoutManager,
                  let clip = tv.enclosingScrollView?.contentView else { return }
            let ns = tv.string as NSString
            let loc = tv.selectedRange().location
            var rect: NSRect
            if ns.length == 0 || (loc >= ns.length && !lm.extraLineFragmentRect.isEmpty) {
                rect = lm.extraLineFragmentRect
            } else {
                let glyph = lm.glyphIndexForCharacter(at: min(loc, ns.length - 1))
                rect = lm.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            }
            rect.origin.y += tv.textContainerOrigin.y
            let maxY = max(0, tv.frame.height - clip.bounds.height)
            let target = min(max(0, (rect.midY - clip.bounds.height / 2).rounded()), maxY)
            guard abs(target - clip.bounds.origin.y) > 1 else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.18
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                clip.animator().setBoundsOrigin(NSPoint(x: clip.bounds.origin.x, y: target))
            }
            tv.enclosingScrollView?.reflectScrolledClipView(clip)
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
            guard !highlighting else { return }
            if style.focusParagraph { updateFocusDim() }
            if style.typewriter {
                // After the edit has been laid out.
                DispatchQueue.main.async { [weak self] in self?.centerCaret() }
            }
            guard style.syntax == .focused, let tv = textView else { return }
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

/// Hosts the editor's scroll view and plays the page-swap transition: the old page (a snapshot) fades
/// and lifts away while the new one settles in. Only layer animations run, so nothing re-lays out mid-flight.
final class EditorContainerView: NSView {
    let scrollView: NSScrollView
    private var overlay: NSImageView?

    init(scrollView: NSScrollView) {
        self.scrollView = scrollView
        super.init(frame: .zero)
        wantsLayer = true
        scrollView.frame = bounds
        scrollView.autoresizingMask = [.width, .height]
        scrollView.wantsLayer = true
        addSubview(scrollView)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    /// A picture of the page as it is now.
    func snapshot() -> NSImage? {
        overlay?.removeFromSuperview()
        overlay = nil
        guard bounds.width > 1, bounds.height > 1,
              let rep = scrollView.bitmapImageRepForCachingDisplay(in: scrollView.bounds) else { return nil }
        scrollView.cacheDisplay(in: scrollView.bounds, to: rep)
        let image = NSImage(size: scrollView.bounds.size)
        image.addRepresentation(rep)
        return image
    }

    func play(from old: NSImage, reduceMotion: Bool) {
        let cover = NSImageView(frame: scrollView.frame)
        cover.image = old
        cover.imageScaling = .scaleAxesIndependently
        cover.wantsLayer = true
        addSubview(cover, positioned: .above, relativeTo: scrollView)
        overlay = cover
        guard let coverLayer = cover.layer, let pageLayer = scrollView.layer else { return }

        let duration: CFTimeInterval = reduceMotion ? 0.14 : 0.26
        let curve = CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.2, 1)  // quick start, soft landing
        let lift: CGFloat = reduceMotion ? 0 : 10

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self, weak cover] in
            cover?.removeFromSuperview()
            if self?.overlay === cover { self?.overlay = nil }
        }
        func animate(_ layer: CALayer, _ key: String, from: Any, to: Any, additive: Bool = false) {
            let a = CABasicAnimation(keyPath: key)
            a.fromValue = from
            a.toValue = to
            a.duration = duration
            a.timingFunction = curve
            a.isAdditive = additive
            a.fillMode = .both
            a.isRemovedOnCompletion = false
            layer.add(a, forKey: "marklySwap." + key)
        }
        // Old page: fade out while drifting up a little.
        animate(coverLayer, "opacity", from: 1, to: 0)
        animate(coverLayer, "transform.translation.y", from: 0, to: -lift, additive: true)
        // New page: fade in while settling up from just below.
        animate(pageLayer, "opacity", from: 0, to: 1)
        animate(pageLayer, "transform.translation.y", from: lift, to: 0, additive: true)
        CATransaction.commit()

        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) { [weak pageLayer] in
            pageLayer?.removeAnimation(forKey: "marklySwap.opacity")
            pageLayer?.removeAnimation(forKey: "marklySwap.transform.translation.y")
        }
    }
}

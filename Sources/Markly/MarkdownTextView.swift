import AppKit

/// Draws block-level decorations: code block backgrounds, blockquote bars and horizontal rules.
final class MarkdownLayoutManager: NSLayoutManager {
    var accent: NSColor = .controlAccentColor

    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        guard let storage = textStorage, let container = textContainers.first else { return }
        let chars = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        let width = container.size.width - container.lineFragmentPadding * 2

        func blockRect(_ charRange: NSRange) -> NSRect {
            let glyphs = glyphRange(forCharacterRange: charRange, actualCharacterRange: nil)
            var rect = NSRect.null
            enumerateLineFragments(forGlyphRange: glyphs) { r, _, _, _, _ in rect = rect.union(r) }
            if charRange.location + charRange.length >= storage.length, !extraLineFragmentRect.isEmpty,
               storage.string.hasSuffix("\n") {
                rect = rect.union(extraLineFragmentRect)
            }
            rect.origin.x = container.lineFragmentPadding
            rect.size.width = width
            return rect.offsetBy(dx: origin.x, dy: origin.y)
        }

        var drawn = Set<Int>()
        storage.enumerateAttribute(.mdCodeBlock, in: chars) { value, range, _ in
            guard value != nil else { return }
            let full = fullRange(of: .mdCodeBlock, value: value, around: range, in: storage)
            guard drawn.insert(full.location).inserted else { return }
            let rect = blockRect(full).insetBy(dx: -10, dy: 0)
            Palette.codeBackground.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
        }

        storage.enumerateAttribute(.mdBlockquote, in: chars) { value, range, _ in
            guard let depth = value as? Int else { return }
            let rect = blockRect(range)
            Palette.accentTint(accent, alpha: 0.55).setFill()
            for i in 0..<depth {
                let bar = NSRect(x: rect.minX + CGFloat(i) * 18 + 2, y: rect.minY + 2, width: 3, height: rect.height - 4)
                NSBezierPath(roundedRect: bar, xRadius: 1.5, yRadius: 1.5).fill()
            }
        }

        storage.enumerateAttribute(.mdImage, in: chars) { value, range, _ in
            guard let box = value as? ImageBox else { return }
            let glyphs = glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            guard glyphs.length > 0 else { return }
            let used = lineFragmentUsedRect(forGlyphAt: NSMaxRange(glyphs) - 1, effectiveRange: nil)
            let rect = NSRect(x: origin.x + container.lineFragmentPadding, y: origin.y + used.maxY + 8,
                              width: box.size.width, height: box.size.height)
            NSGraphicsContext.saveGraphicsState()
            let clip = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
            clip.addClip()
            box.image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            NSGraphicsContext.restoreGraphicsState()
            NSColor.separatorColor.setStroke()
            clip.lineWidth = 1
            clip.stroke()
        }

        storage.enumerateAttribute(.mdRule, in: chars) { value, range, _ in
            guard value != nil else { return }
            let rect = blockRect(range)
            NSColor.separatorColor.setFill()
            NSRect(x: rect.minX, y: rect.midY.rounded(), width: rect.width, height: 1).fill()
        }
    }

    private func fullRange(of key: NSAttributedString.Key, value: Any?, around range: NSRange, in storage: NSTextStorage) -> NSRange {
        var eff = NSRange()
        _ = storage.attribute(key, at: range.location, longestEffectiveRange: &eff,
                              in: NSRange(location: 0, length: storage.length))
        return eff
    }
}

/// The editor. Formatting actions are exposed as `@objc` methods so menu commands can reach
/// the focused editor through the responder chain.
final class MarkdownTextView: NSTextView {
    var maxContentWidth: CGFloat = 720 { didSet { if maxContentWidth != oldValue { updateInsets() } } }
    var onOpenLink: ((String) -> Void)?
    var onColumnWidthChange: ((CGFloat) -> Void)?
    private var lastColumnWidth: CGFloat = 0

    var columnWidth: CGFloat {
        (textContainer?.size.width ?? bounds.width) - 2 * (textContainer?.lineFragmentPadding ?? 5)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateInsets()
    }

    private static let topMargin: CGFloat = 36
    /// Extra room after the last line so the floating word-count pill never covers it.
    private static let bottomMargin: CGFloat = 96

    /// Continue lists on Return and indent them with Tab.
    var smartLists = true
    /// Keep the caret line vertically centred; needs half a screen of space after the last line.
    var typewriter = false { didSet { if typewriter != oldValue { updateInsets() } } }

    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        if typewriter { updateInsets() }
    }

    private var bottomSpace: CGFloat {
        guard typewriter, let visible = enclosingScrollView?.contentView.bounds.height else { return Self.bottomMargin }
        return max(Self.bottomMargin, (visible / 2).rounded())
    }

    override var textContainerOrigin: NSPoint {
        // The inset is symmetric (top + bottom = 2 × height); starting text higher leaves the rest at the bottom.
        NSPoint(x: textContainerInset.width, y: Self.topMargin)
    }

    private func updateInsets() {
        let horizontal = max(28, ((bounds.width - maxContentWidth) / 2).rounded())
        let inset = NSSize(width: horizontal, height: (Self.topMargin + bottomSpace) / 2)
        if textContainerInset != inset { textContainerInset = inset }
        let width = columnWidth
        if abs(width - lastColumnWidth) > 1 {
            lastColumnWidth = width
            onColumnWidthChange?(width)
        }
    }

    // MARK: Mouse: task checkboxes and ⌘-click links

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let index = characterIndex(at: point), let storage = textStorage {
            if let checked = storage.attribute(.mdTaskBox, at: index, effectiveRange: nil) as? Bool {
                var r = NSRange()
                _ = storage.attribute(.mdTaskBox, at: index, effectiveRange: &r)
                replace(r, with: checked ? "[ ]" : "[x]", select: selectedRange())
                return
            }
            if event.modifierFlags.contains(.command),
               let url = storage.attribute(.mdLinkURL, at: index, effectiveRange: nil) as? String {
                onOpenLink?(url)
                return
            }
        }
        super.mouseDown(with: event)
    }

    private func characterIndex(at point: NSPoint) -> Int? {
        guard let lm = layoutManager, let tc = textContainer, let storage = textStorage, storage.length > 0 else { return nil }
        let p = NSPoint(x: point.x - textContainerOrigin.x, y: point.y - textContainerOrigin.y)
        var fraction: CGFloat = 0
        let glyph = lm.glyphIndex(for: p, in: tc, fractionOfDistanceThroughGlyph: &fraction)
        let rect = lm.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: tc)
        guard rect.insetBy(dx: -2, dy: -2).contains(p) else { return nil }
        let index = lm.characterIndexForGlyph(at: glyph)
        return index < storage.length ? index : nil
    }

    // MARK: Editing helpers

    private var ns: NSString { string as NSString }

    func replace(_ range: NSRange, with text: String, select: NSRange) {
        guard shouldChangeText(in: range, replacementString: text) else { return }
        textStorage?.replaceCharacters(in: range, with: text)
        didChangeText()
        setSelectedRange(select)
    }

    private func toggleWrap(_ marker: String) {
        let r = selectedRange()
        let m = (marker as NSString).length
        let selected = ns.substring(with: r)
        // Selection itself contains the markers.
        if selected.count >= 2 * marker.count, selected.hasPrefix(marker), selected.hasSuffix(marker) {
            let inner = String(selected.dropFirst(marker.count).dropLast(marker.count))
            replace(r, with: inner, select: NSRange(location: r.location, length: (inner as NSString).length))
            return
        }
        // Markers surround the selection.
        if r.location >= m, NSMaxRange(r) + m <= ns.length,
           ns.substring(with: NSRange(location: r.location - m, length: m)) == marker,
           ns.substring(with: NSRange(location: NSMaxRange(r), length: m)) == marker {
            let outer = NSRange(location: r.location - m, length: r.length + 2 * m)
            replace(outer, with: selected, select: NSRange(location: r.location - m, length: r.length))
            return
        }
        replace(r, with: marker + selected + marker, select: NSRange(location: r.location + m, length: r.length))
    }

    /// Rewrites every line touched by the selection.
    private func transformLines(_ transform: (String, Int) -> String) {
        let lines = ns.lineRange(for: selectedRange())
        var block = ns.substring(with: lines)
        let trailingNewline = block.hasSuffix("\n")
        if trailingNewline { block.removeLast() }
        let parts = block.components(separatedBy: "\n").enumerated().map { transform($0.element, $0.offset) }
        let result = parts.joined(separator: "\n") + (trailingNewline ? "\n" : "")
        let singleCaret = selectedRange().length == 0 && parts.count == 1
        if singleCaret {
            let end = lines.location + (parts[0] as NSString).length
            replace(lines, with: result, select: NSRange(location: end, length: 0))
        } else {
            replace(lines, with: result, select: NSRange(location: lines.location, length: (result as NSString).length - (trailingNewline ? 1 : 0)))
        }
    }

    private static let blockPrefix = try! NSRegularExpression(pattern: #"^(\s*)(#{1,6}\s+|>\s?|[-*+]\s+\[[ xX]\]\s+|[-*+]\s+|\d+[.)]\s+)?"#)

    private func stripBlockPrefix(_ line: String) -> (indent: String, prefix: String, body: String) {
        let nsl = line as NSString
        guard let m = Self.blockPrefix.firstMatch(in: line, range: NSRange(location: 0, length: nsl.length)) else {
            return ("", "", line)
        }
        let indent = nsl.substring(with: m.range(at: 1))
        let prefix = m.range(at: 2).location == NSNotFound ? "" : nsl.substring(with: m.range(at: 2))
        return (indent, prefix, nsl.substring(from: NSMaxRange(m.range)))
    }

    private func setLinePrefix(_ make: @escaping (Int) -> String, matches: @escaping (String) -> Bool) {
        // If every line already has this prefix, remove it; otherwise apply it.
        let lines = ns.substring(with: ns.lineRange(for: selectedRange())).split(separator: "\n", omittingEmptySubsequences: false)
        let relevant = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let allHave = !relevant.isEmpty && relevant.allSatisfy { matches(stripBlockPrefix(String($0)).prefix) }
        transformLines { line, i in
            let parts = self.stripBlockPrefix(line)
            if line.trimmingCharacters(in: .whitespaces).isEmpty && lines.count > 1 { return line }
            return parts.indent + (allHave ? "" : make(i)) + parts.body
        }
    }

    // MARK: Formatting actions

    @objc func toggleBold(_ sender: Any?) { toggleWrap("**") }
    @objc func toggleItalic(_ sender: Any?) { toggleWrap("*") }
    @objc func toggleStrikethrough(_ sender: Any?) { toggleWrap("~~") }
    @objc func toggleHighlight(_ sender: Any?) { toggleWrap("==") }
    @objc func toggleInlineCode(_ sender: Any?) { toggleWrap("`") }

    @objc func insertLink(_ sender: Any?) {
        let r = selectedRange()
        let s = ns.substring(with: r)
        if s.hasPrefix("http://") || s.hasPrefix("https://") {
            replace(r, with: "[](\(s))", select: NSRange(location: r.location + 1, length: 0))
        } else {
            let text = "[\(s)](url)"
            let urlStart = r.location + (s as NSString).length + 3
            replace(r, with: text, select: s.isEmpty ? NSRange(location: r.location + 1, length: 0) : NSRange(location: urlStart, length: 3))
        }
    }

    // MARK: Selection format state (for the floating format bar)

    private func isWrapped(_ marker: String) -> Bool {
        let r = selectedRange()
        guard r.length > 0 else { return false }
        let m = (marker as NSString).length
        let s = ns.substring(with: r)
        if r.length >= 2 * m, s.hasPrefix(marker), s.hasSuffix(marker) { return true }
        guard r.location >= m, NSMaxRange(r) + m <= ns.length else { return false }
        return ns.substring(with: NSRange(location: r.location - m, length: m)) == marker
            && ns.substring(with: NSRange(location: NSMaxRange(r), length: m)) == marker
    }

    /// The `[text](url)` link whose text is exactly the selection, if any.
    private func enclosingLink() -> (full: NSRange, text: NSRange)? {
        let r = selectedRange()
        guard r.length > 0, r.location > 0, NSMaxRange(r) + 2 < ns.length,
              ns.character(at: r.location - 1) == 91,  // [
              ns.substring(with: NSRange(location: NSMaxRange(r), length: 2)) == "](" else { return nil }
        let after = NSRange(location: NSMaxRange(r) + 2, length: ns.length - NSMaxRange(r) - 2)
        let close = ns.range(of: ")", options: [], range: after)
        let newline = ns.range(of: "\n", options: [], range: after)
        guard close.location != NSNotFound, newline.location == NSNotFound || close.location < newline.location else { return nil }
        return (NSRange(location: r.location - 1, length: NSMaxRange(close) - r.location + 1), r)
    }

    func formatState() -> Set<FormatAction> {
        var state = Set<FormatAction>()
        if isWrapped("**") { state.insert(.bold) }
        if isWrapped("*") && (!isWrapped("**") || isWrapped("***")) { state.insert(.italic) }
        if isWrapped("~~") { state.insert(.strikethrough) }
        if isWrapped("==") { state.insert(.highlight) }
        if isWrapped("`") { state.insert(.code) }
        if enclosingLink() != nil { state.insert(.link) }
        let line = ns.substring(with: ns.lineRange(for: NSRange(location: selectedRange().location, length: 0)))
        if line.hasPrefix("# ") { state.insert(.heading1) }
        if line.hasPrefix("## ") { state.insert(.heading2) }
        if line.hasPrefix(">") { state.insert(.quote) }
        return state
    }

    /// Wraps the selection in a link, keeping the link text selected.
    func applyLink(_ url: String) {
        let r = selectedRange()
        let s = ns.substring(with: r)
        let target = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return }
        replace(r, with: "[\(s)](\(target))", select: NSRange(location: r.location + 1, length: r.length))
    }

    /// Removes the link around the selection, keeping its text selected. Returns false if there was none.
    @discardableResult
    func removeLink() -> Bool {
        guard let link = enclosingLink() else { return false }
        let text = ns.substring(with: link.text)
        replace(link.full, with: text, select: NSRange(location: link.full.location, length: link.text.length))
        return true
    }

    var onCancel: (() -> Bool)?

    /// Esc first dismisses the format bar.
    override func cancelOperation(_ sender: Any?) {
        if onCancel?() == true { return }
        super.cancelOperation(sender)
    }

    private func heading(_ level: Int) {
        let marker = String(repeating: "#", count: level) + " "
        setLinePrefix({ _ in marker }, matches: { $0.trimmingCharacters(in: .whitespaces) == marker.trimmingCharacters(in: .whitespaces) })
    }

    @objc func heading1(_ sender: Any?) { heading(1) }
    @objc func heading2(_ sender: Any?) { heading(2) }
    @objc func heading3(_ sender: Any?) { heading(3) }
    @objc func heading4(_ sender: Any?) { heading(4) }
    @objc func bodyText(_ sender: Any?) {
        transformLines { line, _ in let p = self.stripBlockPrefix(line); return p.indent + p.body }
    }

    @objc func toggleBulletList(_ sender: Any?) {
        setLinePrefix({ _ in "- " }, matches: { ["- ", "* ", "+ "].contains($0) })
    }
    @objc func toggleNumberedList(_ sender: Any?) {
        setLinePrefix({ "\($0 + 1). " }, matches: { $0.first?.isNumber == true })
    }
    @objc func toggleTaskList(_ sender: Any?) {
        setLinePrefix({ _ in "- [ ] " }, matches: { $0.contains("[") })
    }
    @objc func toggleQuote(_ sender: Any?) {
        setLinePrefix({ _ in "> " }, matches: { $0.hasPrefix(">") })
    }

    @objc func insertCodeBlock(_ sender: Any?) {
        let r = selectedRange()
        let s = ns.substring(with: r)
        let lead = (r.location == 0 || ns.character(at: r.location - 1) == 10) ? "" : "\n"
        let text = "\(lead)```\n\(s)\n```\n"
        replace(r, with: text, select: NSRange(location: r.location + (lead as NSString).length + 3, length: 0))
    }

    @objc func insertTable(_ sender: Any?) {
        let r = selectedRange()
        let lead = (r.location == 0 || ns.character(at: r.location - 1) == 10) ? "" : "\n"
        let table = "\(lead)| Column | Column |\n| ------ | ------ |\n|        |        |\n"
        replace(r, with: table, select: NSRange(location: r.location + (lead as NSString).length + 2, length: 6))
    }

    @objc func insertRule(_ sender: Any?) {
        let r = selectedRange()
        let lead = (r.location == 0 || ns.character(at: r.location - 1) == 10) ? "" : "\n"
        replace(r, with: "\(lead)\n---\n\n", select: NSRange(location: r.location + (lead as NSString).length + 6, length: 0))
    }

    // MARK: List continuation and indentation

    private static let listItem = try! NSRegularExpression(pattern: #"^(\s*)(?:(>\s?)+)?([-*+]|(\d+)([.)]))(\s+)(\[[ xX]\]\s+)?"#)

    private func currentListMatch() -> (line: NSRange, match: NSTextCheckingResult, text: String)? {
        guard smartLists else { return nil }
        let caret = selectedRange()
        let lineRange = ns.lineRange(for: NSRange(location: caret.location, length: 0))
        var line = ns.substring(with: lineRange)
        if line.hasSuffix("\n") { line.removeLast() }
        guard let m = Self.listItem.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) else { return nil }
        return (lineRange, m, line)
    }

    override func insertNewline(_ sender: Any?) {
        guard selectedRange().length == 0, let (lineRange, m, line) = currentListMatch() else {
            super.insertNewline(sender)
            return
        }
        let nsl = line as NSString
        let caret = selectedRange().location
        guard caret >= lineRange.location + NSMaxRange(m.range) else {
            super.insertNewline(sender)
            return
        }
        let body = nsl.substring(from: NSMaxRange(m.range)).trimmingCharacters(in: .whitespaces)
        if body.isEmpty {
            // Empty item: end the list.
            let r = NSRange(location: lineRange.location, length: nsl.length)
            replace(r, with: "", select: NSRange(location: lineRange.location, length: 0))
            return
        }
        var prefix = nsl.substring(with: m.range)
        if m.range(at: 4).location != NSNotFound, let n = Int(nsl.substring(with: m.range(at: 4))) {
            prefix = nsl.substring(to: m.range(at: 4).location) + "\(n + 1)" + nsl.substring(with: NSRange(location: m.range(at: 5).location, length: NSMaxRange(m.range) - m.range(at: 5).location))
        }
        if m.range(at: 7).location != NSNotFound {
            prefix = prefix.replacingOccurrences(of: "[x]", with: "[ ]").replacingOccurrences(of: "[X]", with: "[ ]")
        }
        insertText("\n" + prefix, replacementRange: selectedRange())
    }

    override func insertTab(_ sender: Any?) {
        guard let (lineRange, _, _) = currentListMatch() else { super.insertTab(sender); return }
        let caret = selectedRange()
        replace(NSRange(location: lineRange.location, length: 0), with: "    ",
                select: NSRange(location: caret.location + 4, length: caret.length))
    }

    override func insertBacktab(_ sender: Any?) {
        guard let (lineRange, _, line) = currentListMatch() else { super.insertBacktab(sender); return }
        let spaces = line.prefix(4).prefix { $0 == " " }.count
        let remove = spaces > 0 ? spaces : (line.hasPrefix("\t") ? 1 : 0)
        guard remove > 0 else { return }
        let caret = selectedRange()
        replace(NSRange(location: lineRange.location, length: remove), with: "",
                select: NSRange(location: max(lineRange.location, caret.location - remove), length: caret.length))
    }
}

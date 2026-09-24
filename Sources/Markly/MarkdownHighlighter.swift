import AppKit

extension NSAttributedString.Key {
    static let mdCodeBlock = NSAttributedString.Key("mdCodeBlock")
    static let mdBlockquote = NSAttributedString.Key("mdBlockquote")
    static let mdRule = NSAttributedString.Key("mdRule")
    static let mdTaskBox = NSAttributedString.Key("mdTaskBox")
    static let mdLinkURL = NSAttributedString.Key("mdLinkURL")
    static let mdImage = NSAttributedString.Key("mdImage")
}

enum Palette {
    static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
    }

    static func accentTint(_ accent: NSColor, alpha: CGFloat) -> NSColor {
        NSColor(name: nil) { appearance in
            var result = accent
            appearance.performAsCurrentDrawingAppearance {
                result = (accent.usingColorSpace(.sRGB) ?? accent).withAlphaComponent(alpha)
            }
            return result
        }
    }
}

/// Applies live Markdown styling to a text storage. Markers (`**`, `#`, `[]()`…) are dimmed,
/// or collapsed entirely on lines that don't hold the caret, depending on `SyntaxVisibility`.
final class MarkdownHighlighter {
    var style = EditorStyle()
    /// Returns a loaded image for a Markdown image source, or nil if unavailable (yet).
    var imageProvider: ((String) -> NSImage?)?
    /// Width of the text column, used to size inline images.
    var columnWidth: CGFloat = 640

    private static func rx(_ p: String, _ o: NSRegularExpression.Options = []) -> NSRegularExpression {
        try! NSRegularExpression(pattern: p, options: o)
    }

    private let fenceRx = rx(#"^\s{0,3}(`{3,}|~{3,})(.*)$"#)
    private let mathFenceRx = rx(#"^\s*\$\$\s*$"#)
    private let headingRx = rx(#"^(#{1,6})(\s+)(.*)$"#)
    private let quoteRx = rx(#"^(\s*(?:>\s?)+)"#)
    private let listRx = rx(#"^(\s*)([-*+]|\d{1,9}[.)])(\s+)(\[[ xX]\]\s)?"#)
    private let ruleRx = rx(#"^\s{0,3}([-*_])(\s*\1){2,}\s*$"#)
    private let tableRx = rx(#"^\s*\|.*\|\s*$"#)
    private let imageLineRx = rx(#"^\s*!\[[^\]\n]*\]\(<?([^)\s>]+)>?(?:\s+"[^"]*")?\)\s*$"#)

    private let inlineCodeRx = rx(#"(`+)(?!`)(.+?)(?<!`)\1(?!`)"#)
    private let imageRx = rx(#"!\[([^\]\n]*)\]\(([^)\n]*)\)"#)
    private let linkRx = rx(#"(?<!!)\[([^\]\n]+)\]\(([^)\n]*)\)"#)
    private let autolinkRx = rx(#"<?\bhttps?://[^\s<>()]+[^\s<>().,;:!?'"]>?"#)
    private let boldRx = rx(#"(\*\*|__)(?=\S)(.+?)(?<=\S)\1"#)
    private let italicStarRx = rx(#"(?<![*\\\w])\*(?=[^\s*])(.+?)(?<=[^\s*\\])\*(?![*\w])"#)
    private let italicUnderRx = rx(#"(?<![_\w])_(?=[^\s_])(.+?)(?<=[^\s_])_(?![_\w])"#)
    private let strikeRx = rx(#"~~(?=\S)(.+?)(?<=\S)~~"#)
    private let markRx = rx(#"==(?=\S)(.+?)(?<=\S)=="#)
    private let mathRx = rx(#"(?<![\\$])\$(?=\S)([^$\n]+?)(?<=\S)\$(?!\$)"#)

    private let headingScale: [CGFloat] = [1.85, 1.5, 1.28, 1.14, 1.05, 1.0]

    // MARK: Fonts

    var baseFont: NSFont { style.font.font(size: style.fontSize) }
    var codeFont: NSFont { .monospacedSystemFont(ofSize: style.fontSize * 0.9, weight: .regular) }
    var accent: NSColor { style.accent.nsColor }
    var theme: Theme { style.accent.theme }

    var baseParagraph: NSMutableParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.lineHeightMultiple = style.lineSpacing
        p.paragraphSpacing = style.fontSize * 0.2
        return p
    }

    var typingAttributes: [NSAttributedString.Key: Any] {
        [.font: baseFont, .foregroundColor: theme.text, .paragraphStyle: baseParagraph]
    }

    // MARK: Highlight

    /// Text that changes how *other* lines are styled (fences, math blocks). Edits touching these need a full pass.
    static func affectsBlocks(_ s: String) -> Bool {
        s.contains("```") || s.contains("~~~") || s.contains("$$")
    }

    /// - Parameters:
    ///   - active: character range of the lines containing the selection (or nil).
    ///   - limits: if given, only lines intersecting these ranges are restyled. Every line is still scanned
    ///     (cheaply) to track code fences, so blocks stay correct.
    func highlight(_ storage: NSTextStorage, active: NSRange?, limits: [NSRange]? = nil) {
        let text = storage.string as NSString
        let full = NSRange(location: 0, length: text.length)
        storage.beginEditing()
        defer { storage.endEditing() }

        if limits == nil { storage.setAttributes(typingAttributes, range: full) }
        guard text.length > 0 else { return }

        func shouldStyle(_ lineRange: NSRange) -> Bool {
            guard let limits else { return true }
            return limits.contains { l in
                NSIntersectionRange(l, lineRange).length > 0
                    || (l.length == 0 && l.location >= lineRange.location && l.location <= NSMaxRange(lineRange))
            }
        }

        var syntaxRanges: [(NSRange, Bool)] = []  // (range, collapsible)
        var inFence: String? = nil
        var fenceStart = 0
        var inMath = false
        var mathStart = 0
        var loc = 0

        func isActive(_ lineRange: NSRange) -> Bool {
            if style.syntax == .always { return true }
            if style.syntax == .hidden { return false }
            guard let a = active else { return false }
            if NSIntersectionRange(a, lineRange).length > 0 { return true }
            return a.location == lineRange.location || (a.location == NSMaxRange(lineRange) && a.location == text.length)
        }

        while loc < text.length {
            let lineRange = text.lineRange(for: NSRange(location: loc, length: 0))
            var content = lineRange
            while content.length > 0 {
                let c = text.character(at: NSMaxRange(content) - 1)
                if c == 10 || c == 13 { content.length -= 1 } else { break }
            }
            let line = text.substring(with: content)
            let lineNS = line as NSString
            let lineFull = NSRange(location: 0, length: lineNS.length)
            let activeLine = isActive(lineRange)
            loc = NSMaxRange(lineRange)

            func abs(_ r: NSRange) -> NSRange { NSRange(location: content.location + r.location, length: r.length) }

            if !shouldStyle(lineRange) {
                // Track block state only, mirroring the branches below.
                if let fence = inFence {
                    if line.trimmingCharacters(in: .whitespaces).hasPrefix(fence) { inFence = nil }
                } else if let m = fenceRx.firstMatch(in: line, range: lineFull) {
                    inFence = String(lineNS.substring(with: m.range(at: 1)).prefix(3))
                    fenceStart = lineRange.location
                } else if inMath {
                    if mathFenceRx.firstMatch(in: line, range: lineFull) != nil { inMath = false }
                } else if mathFenceRx.firstMatch(in: line, range: lineFull) != nil {
                    inMath = true
                    mathStart = lineRange.location
                }
                continue
            }
            if limits != nil { storage.setAttributes(typingAttributes, range: lineRange) }

            // Fenced code blocks
            if let fence = inFence {
                storage.addAttributes([.font: codeFont, .mdCodeBlock: true], range: lineRange)
                if line.trimmingCharacters(in: .whitespaces).hasPrefix(fence) {
                    storage.addAttribute(.foregroundColor, value: theme.syntax, range: content)
                    storage.addAttribute(.mdCodeBlock, value: fenceStart, range: lineRange)
                    inFence = nil
                } else {
                    storage.addAttribute(.mdCodeBlock, value: fenceStart, range: lineRange)
                }
                continue
            }
            if let m = fenceRx.firstMatch(in: line, range: lineFull) {
                let marker = lineNS.substring(with: m.range(at: 1))
                inFence = String(marker.prefix(3))
                fenceStart = lineRange.location
                storage.addAttributes([.font: codeFont, .foregroundColor: theme.syntax, .mdCodeBlock: fenceStart], range: lineRange)
                if m.range(at: 2).length > 0 {
                    storage.addAttribute(.foregroundColor, value: accent, range: abs(m.range(at: 2)))
                }
                continue
            }

            // $$ math blocks
            if inMath || mathFenceRx.firstMatch(in: line, range: lineFull) != nil {
                if !inMath { inMath = true; mathStart = lineRange.location }
                else if mathFenceRx.firstMatch(in: line, range: lineFull) != nil { inMath = false }
                storage.addAttributes([.font: codeFont, .foregroundColor: theme.secondary, .mdCodeBlock: mathStart], range: lineRange)
                continue
            }

            if lineNS.length == 0 { continue }

            // Horizontal rule
            if ruleRx.firstMatch(in: line, range: lineFull) != nil {
                storage.addAttributes([.foregroundColor: theme.syntax, .mdRule: true], range: content)
                continue
            }

            // Headings
            if let m = headingRx.firstMatch(in: line, range: lineFull) {
                let level = m.range(at: 1).length
                let size = style.fontSize * headingScale[level - 1]
                let font = style.font.font(size: size, weight: level <= 2 ? .bold : .semibold)
                let p = baseParagraph
                p.paragraphSpacingBefore = level <= 2 ? style.fontSize * 0.6 : style.fontSize * 0.3
                p.lineHeightMultiple = max(1.1, style.lineSpacing - 0.15)
                storage.addAttributes([.font: font, .paragraphStyle: p], range: content)
                let markerRange = NSRange(location: 0, length: m.range(at: 1).length + m.range(at: 2).length)
                syntaxRanges.append((abs(markerRange), !activeLine))
                applyInline(storage, line: lineNS, offset: content.location, active: activeLine, syntax: &syntaxRanges)
                continue
            }

            // Tables: monospaced so columns line up
            if tableRx.firstMatch(in: line, range: lineFull) != nil {
                storage.addAttribute(.font, value: codeFont, range: content)
                let pipes = Self.rx(#"\||(?<=\|)\s*:?-{2,}:?\s*(?=\|)"#)
                for m in pipes.matches(in: line, range: lineFull) {
                    storage.addAttribute(.foregroundColor, value: theme.syntax, range: abs(m.range))
                }
                continue
            }

            // Image on its own line: reserve room below it and let the layout manager draw a preview.
            if style.imagePreview != .off, let m = imageLineRx.firstMatch(in: line, range: lineFull),
               let image = imageProvider?(lineNS.substring(with: m.range(at: 1))) {
                let maxWidth = max(80, columnWidth * style.imagePreview.fraction)
                let maxHeight = 640 * style.imagePreview.fraction
                let scale = min(1, maxWidth / image.size.width, maxHeight / image.size.height)
                let size = NSSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
                let p = baseParagraph
                p.paragraphSpacing = size.height + 18
                storage.addAttribute(.paragraphStyle, value: p, range: lineRange)
                storage.addAttribute(.mdImage, value: ImageBox(image: image, size: size), range: content)
                applyInline(storage, line: lineNS, offset: content.location, active: activeLine, syntax: &syntaxRanges)
                if !activeLine { syntaxRanges.append((content, true)) }
                continue
            }

            var inlineStart = 0

            // Blockquotes
            if let m = quoteRx.firstMatch(in: line, range: lineFull) {
                let depth = lineNS.substring(with: m.range).filter { $0 == ">" }.count
                let p = baseParagraph
                let indent = CGFloat(depth) * 18
                p.firstLineHeadIndent = indent
                p.headIndent = indent
                storage.addAttributes([.foregroundColor: theme.secondary, .paragraphStyle: p, .mdBlockquote: depth], range: lineRange)
                syntaxRanges.append((abs(m.range), !activeLine))
                inlineStart = m.range.length
            }

            // Lists and tasks
            if let m = listRx.firstMatch(in: line, range: NSRange(location: inlineStart, length: lineFull.length - inlineStart)),
               m.range.location == inlineStart {
                let prefix = lineNS.substring(with: NSRange(location: 0, length: NSMaxRange(m.range)))
                let width = (prefix as NSString).size(withAttributes: [.font: baseFont]).width
                let p = (storage.attribute(.paragraphStyle, at: content.location, effectiveRange: nil) as? NSParagraphStyle)?
                    .mutableCopy() as? NSMutableParagraphStyle ?? baseParagraph
                p.headIndent = p.firstLineHeadIndent + width
                p.paragraphSpacing = style.fontSize * 0.1
                storage.addAttribute(.paragraphStyle, value: p, range: lineRange)
                storage.addAttributes([.foregroundColor: accent], range: abs(m.range(at: 2)))
                if m.range(at: 2).length == 1 {
                    storage.addAttribute(.font, value: style.font.font(size: style.fontSize, weight: .bold), range: abs(m.range(at: 2)))
                }
                if m.range(at: 4).location != NSNotFound {
                    let box = NSRange(location: m.range(at: 4).location, length: 3)
                    let checked = lineNS.substring(with: box).lowercased() == "[x]"
                    storage.addAttributes([
                        .font: NSFont.monospacedSystemFont(ofSize: style.fontSize, weight: .bold),
                        .foregroundColor: accent,
                        .mdTaskBox: checked,
                        .cursor: NSCursor.pointingHand,
                    ], range: abs(box))
                    if checked {
                        let rest = NSRange(location: NSMaxRange(m.range), length: lineNS.length - NSMaxRange(m.range))
                        storage.addAttributes([
                            .foregroundColor: theme.secondary,
                            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                            .strikethroughColor: theme.syntax,
                        ], range: abs(rest))
                    }
                }
                inlineStart = NSMaxRange(m.range)
            }

            applyInline(storage, line: lineNS, offset: content.location, from: inlineStart, active: activeLine, syntax: &syntaxRanges)
        }

        // Syntax markers go last so they override any font set above.
        let hiddenFont = NSFont.systemFont(ofSize: 0.01)
        for (r, collapse) in syntaxRanges where r.length > 0 {
            if collapse {
                storage.addAttributes([.font: hiddenFont, .foregroundColor: NSColor.clear], range: r)
            } else {
                storage.addAttribute(.foregroundColor, value: theme.syntax, range: r)
            }
        }
    }

    // MARK: Inline

    private func applyInline(_ storage: NSTextStorage, line: NSString, offset: Int, from start: Int = 0,
                             active: Bool, syntax: inout [(NSRange, Bool)]) {
        let scope = NSRange(location: start, length: line.length - start)
        guard scope.length > 0 else { return }
        let str = line as String
        var protected: [NSRange] = []
        func abs(_ r: NSRange) -> NSRange { NSRange(location: offset + r.location, length: r.length) }
        func free(_ r: NSRange) -> Bool { !protected.contains { NSIntersectionRange($0, r).length > 0 } }
        func mark(_ r: NSRange) { syntax.append((abs(r), !active)) }

        for m in inlineCodeRx.matches(in: str, range: scope) {
            let fence = m.range(at: 1).length
            storage.addAttributes([.font: codeFont, .backgroundColor: theme.codeBackground, .foregroundColor: theme.text], range: abs(m.range))
            mark(NSRange(location: m.range.location, length: fence))
            mark(NSRange(location: NSMaxRange(m.range) - fence, length: fence))
            protected.append(m.range)
        }

        for m in mathRx.matches(in: str, range: scope) where free(m.range) {
            storage.addAttributes([.font: codeFont, .foregroundColor: accent], range: abs(m.range))
            protected.append(m.range)
        }

        for m in imageRx.matches(in: str, range: scope) where free(m.range) {
            storage.addAttributes([.foregroundColor: accent, .mdLinkURL: line.substring(with: m.range(at: 2))], range: abs(m.range(at: 1)))
            mark(NSRange(location: m.range.location, length: 2))
            mark(NSRange(location: NSMaxRange(m.range(at: 1)), length: NSMaxRange(m.range) - NSMaxRange(m.range(at: 1))))
            protected.append(m.range)
        }

        for m in linkRx.matches(in: str, range: scope) where free(m.range) {
            storage.addAttributes([
                .foregroundColor: accent,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: Palette.accentTint(accent, alpha: 0.4),
                .mdLinkURL: line.substring(with: m.range(at: 2)),
            ], range: abs(m.range(at: 1)))
            mark(NSRange(location: m.range.location, length: 1))
            mark(NSRange(location: NSMaxRange(m.range(at: 1)), length: NSMaxRange(m.range) - NSMaxRange(m.range(at: 1))))
            // Emphasis inside link text is still allowed, so only protect the URL part.
            protected.append(NSRange(location: NSMaxRange(m.range(at: 1)), length: NSMaxRange(m.range) - NSMaxRange(m.range(at: 1))))
        }

        for m in autolinkRx.matches(in: str, range: scope) where free(m.range) {
            let url = line.substring(with: m.range).trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
            storage.addAttributes([.foregroundColor: accent, .underlineStyle: NSUnderlineStyle.single.rawValue,
                                   .underlineColor: Palette.accentTint(accent, alpha: 0.4), .mdLinkURL: url], range: abs(m.range))
            protected.append(m.range)
        }

        func wrapped(_ regex: NSRegularExpression, marker: Int, apply: (NSRange) -> Void) {
            for m in regex.matches(in: str, range: scope) where free(m.range) {
                let inner = NSRange(location: m.range.location + marker, length: m.range.length - marker * 2)
                apply(abs(inner))
                mark(NSRange(location: m.range.location, length: marker))
                mark(NSRange(location: NSMaxRange(m.range) - marker, length: marker))
            }
        }

        wrapped(boldRx, marker: 2) { addTrait(.bold, storage, $0) }
        wrapped(italicStarRx, marker: 1) { addTrait(.italic, storage, $0) }
        wrapped(italicUnderRx, marker: 1) { addTrait(.italic, storage, $0) }
        wrapped(strikeRx, marker: 2) {
            storage.addAttributes([.strikethroughStyle: NSUnderlineStyle.single.rawValue, .foregroundColor: theme.secondary], range: $0)
        }
        wrapped(markRx, marker: 2) {
            storage.addAttribute(.backgroundColor, value: theme.mark, range: $0)
        }
    }

    private func addTrait(_ trait: NSFontDescriptor.SymbolicTraits, _ storage: NSTextStorage, _ range: NSRange) {
        storage.enumerateAttribute(.font, in: range) { value, r, _ in
            guard let f = value as? NSFont else { return }
            let d = f.fontDescriptor.withSymbolicTraits(f.fontDescriptor.symbolicTraits.union(trait))
            var nf = NSFont(descriptor: d, size: f.pointSize) ?? f
            if trait == .bold, !nf.fontDescriptor.symbolicTraits.contains(.bold) {
                nf = NSFontManager.shared.convert(f, toHaveTrait: .boldFontMask)
            }
            if trait == .italic, !nf.fontDescriptor.symbolicTraits.contains(.italic) {
                nf = NSFontManager.shared.convert(f, toHaveTrait: .italicFontMask)
            }
            storage.addAttribute(.font, value: nf, range: r)
        }
    }
}

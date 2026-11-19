import Foundation

/// Full-text search across the notes in the sidebar. Plain file reads, no index: notes stay plain files and
/// nothing is written next to them. Runs off the main thread (see `SidebarView`).
enum NoteSearch {
    struct Hit: Identifiable, Hashable, Sendable {
        let url: URL
        /// Range of the match in the note (UTF-16, as `NSString`/`NSTextView` count).
        let range: NSRange
        /// The matching line, trimmed and shortened around the match.
        let snippet: String
        /// Range of the match inside `snippet`, for highlighting.
        let snippetMatch: NSRange
        var id: String { "\(url.path)#\(range.location)" }
    }

    /// Notes larger than this are skipped; they're almost certainly not prose.
    static let maxFileSize = 4 << 20

    /// Case- and diacritic-insensitive matches of `query` in each file, in file order. `overrides` supplies
    /// text for files whose current contents aren't on disk yet (the open note with unsaved edits).
    static func search(_ query: String, in files: [URL], overrides: [URL: String] = [:],
                       perFile: Int = 5, limit: Int = 300, isCancelled: () -> Bool = { false }) -> [Hit] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        var hits: [Hit] = []
        for url in files {
            if hits.count >= limit || isCancelled() { break }
            guard let text = overrides[url] ?? read(url) else { continue }
            hits += matches(of: needle, in: text, url: url, max: min(perFile, limit - hits.count))
        }
        return hits
    }

    static func matches(of needle: String, in text: String, url: URL, max: Int) -> [Hit] {
        let ns = text as NSString
        var hits: [Hit] = []
        var start = 0
        while hits.count < max, start < ns.length {
            let found = ns.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive],
                                 range: NSRange(location: start, length: ns.length - start))
            guard found.location != NSNotFound, found.length > 0 else { break }
            let line = ns.lineRange(for: found)
            let (snippet, inSnippet) = makeSnippet(ns.substring(with: line), match: NSRange(location: found.location - line.location, length: found.length))
            hits.append(Hit(url: url, range: found, snippet: snippet, snippetMatch: inSnippet))
            // One hit per line keeps the list readable.
            start = NSMaxRange(line)
        }
        return hits
    }

    /// Trims the line and keeps a window around the match so the match is visible in a narrow sidebar.
    static func makeSnippet(_ line: String, match: NSRange, before: Int = 24, total: Int = 120) -> (String, NSRange) {
        let ns = line as NSString
        var lo = 0, hi = ns.length
        while lo < match.location, let c = Unicode.Scalar(ns.character(at: lo)), CharacterSet.whitespacesAndNewlines.contains(c) { lo += 1 }
        while hi > NSMaxRange(match), let c = Unicode.Scalar(ns.character(at: hi - 1)), CharacterSet.whitespacesAndNewlines.contains(c) { hi -= 1 }
        var prefix = "", suffix = ""
        if match.location - lo > before {
            lo = ns.rangeOfComposedCharacterSequence(at: match.location - before).location
            prefix = "…"
        }
        if hi - lo > total, NSMaxRange(match) < lo + total {
            hi = NSMaxRange(ns.rangeOfComposedCharacterSequence(at: lo + total - 1))
            suffix = "…"
        }
        let body = ns.substring(with: NSRange(location: lo, length: hi - lo))
        let offset = (prefix as NSString).length
        return (prefix + body + suffix, NSRange(location: match.location - lo + offset, length: match.length))
    }

    private static func read(_ url: URL) -> String? {
        guard let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, size <= maxFileSize else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

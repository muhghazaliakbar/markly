import AppKit
import XCTest
@testable import Markly

@MainActor
final class EditorTests: XCTestCase {
    private func makeEditor(_ text: String, select: NSRange? = nil) -> MarkdownTextView {
        let storage = NSTextStorage()
        let layout = MarkdownLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: NSSize(width: 600, height: CGFloat.greatestFiniteMagnitude))
        layout.addTextContainer(container)
        let tv = MarkdownTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400), textContainer: container)
        tv.allowsUndo = true
        tv.string = text
        tv.setSelectedRange(select ?? NSRange(location: (text as NSString).length, length: 0))
        return tv
    }

    func testBoldWrapsAndUnwraps() {
        let tv = makeEditor("hello world", select: NSRange(location: 6, length: 5))
        tv.toggleBold(nil)
        XCTAssertEqual(tv.string, "hello **world**")
        XCTAssertEqual(tv.selectedRange(), NSRange(location: 8, length: 5))
        tv.toggleBold(nil)
        XCTAssertEqual(tv.string, "hello world")
    }

    func testHeadingToggle() {
        let tv = makeEditor("Title")
        tv.heading2(nil)
        XCTAssertEqual(tv.string, "## Title")
        tv.heading1(nil)
        XCTAssertEqual(tv.string, "# Title")
        tv.heading1(nil)
        XCTAssertEqual(tv.string, "Title")
    }

    func testBulletListOverMultipleLines() {
        let tv = makeEditor("one\ntwo", select: NSRange(location: 0, length: 7))
        tv.toggleBulletList(nil)
        XCTAssertEqual(tv.string, "- one\n- two")
        tv.toggleNumberedList(nil)
        XCTAssertEqual(tv.string, "1. one\n2. two")
    }

    func testListContinuation() {
        let tv = makeEditor("- [x] done")
        tv.insertNewline(nil)
        XCTAssertEqual(tv.string, "- [x] done\n- [ ] ")
        tv.insertNewline(nil)  // empty item ends the list
        XCTAssertEqual(tv.string, "- [x] done\n")

        let numbered = makeEditor("3. third")
        numbered.insertNewline(nil)
        XCTAssertEqual(numbered.string, "3. third\n4. ")
    }

    func testIndentListItem() {
        let tv = makeEditor("- item")
        tv.insertTab(nil)
        XCTAssertEqual(tv.string, "    - item")
        tv.insertBacktab(nil)
        XCTAssertEqual(tv.string, "- item")
    }

    func testLinkInsertion() {
        let tv = makeEditor("see docs", select: NSRange(location: 4, length: 4))
        tv.insertLink(nil)
        XCTAssertEqual(tv.string, "see [docs](url)")
        XCTAssertEqual((tv.string as NSString).substring(with: tv.selectedRange()), "url")
    }

    func testHighlighterHidesInactiveSyntax() {
        let storage = NSTextStorage(string: "**bold**\nplain")
        let h = MarkdownHighlighter()
        h.highlight(storage, active: NSRange(location: 9, length: 5))
        let markerFont = storage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertLessThan(markerFont?.pointSize ?? 99, 1)
        let bodyFont = storage.attribute(.font, at: 3, effectiveRange: nil) as? NSFont
        XCTAssertTrue(bodyFont?.fontDescriptor.symbolicTraits.contains(.bold) ?? false)

        h.highlight(storage, active: NSRange(location: 0, length: 0))
        let visible = storage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        XCTAssertGreaterThan(visible?.pointSize ?? 0, 1)
    }

    func testTaskBoxAttribute() {
        let storage = NSTextStorage(string: "- [ ] todo\n- [x] done")
        MarkdownHighlighter().highlight(storage, active: nil)
        XCTAssertEqual(storage.attribute(.mdTaskBox, at: 3, effectiveRange: nil) as? Bool, false)
        XCTAssertEqual(storage.attribute(.mdTaskBox, at: 14, effectiveRange: nil) as? Bool, true)
    }

    func testRendererHighlight() {
        XCTAssertTrue(MarkdownRenderer.html(from: "a ==b== c").contains("<mark>b</mark>"))
    }

    /// Styling only the edited lines must give the same result as restyling everything.
    func testIncrementalHighlightMatchesFull() {
        let doc = "# Title\n\nSome **bold** text\n\n```swift\nlet x = 1\n```\n\n- [ ] task\n> quote"
        let h = MarkdownHighlighter()
        let active = NSRange(location: 0, length: 8)

        let incremental = NSTextStorage(string: doc)
        h.highlight(incremental, active: active)
        // Edit inside the code block, then restyle just that line.
        let editAt = (doc as NSString).range(of: "let x").location
        incremental.replaceCharacters(in: NSRange(location: editAt, length: 3), with: "var")
        let line = (incremental.string as NSString).lineRange(for: NSRange(location: editAt, length: 0))
        h.highlight(incremental, active: active, limits: [line, active])

        let full = NSTextStorage(string: incremental.string)
        h.highlight(full, active: active)

        for key: NSAttributedString.Key in [.font, .foregroundColor, .mdCodeBlock, .mdTaskBox, .mdBlockquote] {
            var i = 0
            while i < full.length {
                let a = full.attribute(key, at: i, effectiveRange: nil) as? NSObject
                let b = incremental.attribute(key, at: i, effectiveRange: nil) as? NSObject
                XCTAssertEqual(a, b, "\(key.rawValue) differs at \(i)")
                i += 1
            }
        }
    }

    func testClickOutsidePanelCloses() {
        // 1000×600 window with a toolbar; detail pane from x=260; panel is the right-most 312 pt.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 600),
                              styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: true)
        window.toolbar = NSToolbar()
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 600))
        window.contentView = content
        let monitor = ClickMonitorView(frame: NSRect(x: 260, y: 0, width: 740, height: 600))
        content.addSubview(monitor)
        monitor.isActive = true
        monitor.excluded = CGRect(x: 688, y: 0, width: 312, height: 600)  // SwiftUI global, top-left origin
        let midY = window.contentLayoutRect.midY

        XCTAssertTrue(monitor.shouldClose(forClickAt: NSPoint(x: 500, y: midY)), "click in the editor")
        XCTAssertFalse(monitor.shouldClose(forClickAt: NSPoint(x: 800, y: midY)), "click inside the panel")
        XCTAssertFalse(monitor.shouldClose(forClickAt: NSPoint(x: 100, y: midY)), "click in the file sidebar")
        XCTAssertFalse(monitor.shouldClose(forClickAt: NSPoint(x: 500, y: window.contentLayoutRect.maxY + 5)),
                       "click in the toolbar")
        monitor.isActive = false
        XCTAssertFalse(monitor.shouldClose(forClickAt: NSPoint(x: 500, y: midY)), "panel already closed")
    }

    func testContentSecurityPolicyFollowsPrivacySettings() {
        let open = MarkdownRenderer.contentSecurityPolicy(network: true, remoteImages: true)
        XCTAssertTrue(open.contains("script-src 'unsafe-inline' https://cdn.jsdelivr.net"))
        XCTAssertTrue(open.contains("img-src file: data: https: http:"))

        let closed = MarkdownRenderer.contentSecurityPolicy(network: false, remoteImages: false)
        XCTAssertFalse(closed.contains("jsdelivr"))
        XCTAssertFalse(closed.contains("https:"))
        XCTAssertTrue(closed.hasPrefix("default-src 'none'"))
    }

    func testParagraphRangeForFocusMode() {
        let ns = "first line\nsecond line\n\nthird\n" as NSString
        let p1 = EditorView.Coordinator.paragraphRange(in: ns, at: 3)
        XCTAssertEqual(ns.substring(with: p1), "first line\nsecond line\n")
        let p2 = EditorView.Coordinator.paragraphRange(in: ns, at: ns.range(of: "third").location)
        XCTAssertEqual(ns.substring(with: p2), "third\n")
    }

    func testSmartListsCanBeTurnedOff() {
        let tv = makeEditor("- item")
        tv.smartLists = false
        tv.insertNewline(nil)
        XCTAssertEqual(tv.string, "- item\n")
    }
}

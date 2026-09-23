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
}

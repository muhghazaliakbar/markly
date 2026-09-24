import AppKit
import XCTest
@testable import Markly

final class ThemeTests: XCTestCase {
    func testMarklyIsTheDefaultAccent() {
        XCTAssertEqual(EditorStyle().accent, .markly)
        XCTAssertTrue(AccentChoice.markly.theme.warm)
        XCTAssertFalse(AccentChoice.blue.theme.warm)
        XCTAssertFalse(AccentChoice.system.theme.warm)
    }

    func testHighlighterUsesThemeInk() {
        let highlighter = MarkdownHighlighter()
        for (accent, theme) in [(AccentChoice.markly, Theme.markly), (.blue, Theme.system)] {
            highlighter.style = EditorStyle(accent: accent)
            let storage = NSTextStorage(string: "Plain **bold**\n\n> quote")
            highlighter.highlight(storage, active: nil)
            XCTAssertEqual(storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor, theme.text)
            let quote = (storage.string as NSString).range(of: "quote").location
            XCTAssertEqual(storage.attribute(.foregroundColor, at: quote, effectiveRange: nil) as? NSColor, theme.secondary)
        }
    }

    func testWarmPreviewPageLayersBrandCSSAfterAccent() {
        let warm = MarkdownRenderer.page(title: "A", body: "", baseURL: nil, accentHex: "#d92d63", warm: true)
        let plain = MarkdownRenderer.page(title: "A", body: "", baseURL: nil, accentHex: "#d92d63")
        XCTAssertFalse(plain.contains("#fffbfa"))
        let accent = warm.range(of: "--accent: #d92d63; }")!
        let brand = warm.range(of: "--bg: #fffbfa")!
        // The brand block comes last so its dark-mode accent wins over the injected light hex.
        XCTAssertLessThan(accent.lowerBound, brand.lowerBound)
        XCTAssertTrue(warm.contains("--accent: #ff5c8d"))
    }
}

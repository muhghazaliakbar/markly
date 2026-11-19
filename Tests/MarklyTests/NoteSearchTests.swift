import XCTest
@testable import Markly

final class NoteSearchTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("markly-search-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Sub"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func note(_ path: String, _ text: String) throws -> URL {
        let url = root.appendingPathComponent(path)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testFindsTextAcrossNotesIgnoringCaseAndAccents() throws {
        let a = try note("A.md", "# Groceries\n\nBuy coffee beans\n")
        let b = try note("Sub/B.md", "Notes from the Café meeting\nnothing here\n")
        let c = try note("Sub/C.md", "Unrelated")

        let hits = NoteSearch.search("cafe", in: [a, b, c])
        XCTAssertEqual(hits.map(\.url), [b])
        XCTAssertEqual(hits[0].snippet, "Notes from the Café meeting")
        XCTAssertEqual((hits[0].snippet as NSString).substring(with: hits[0].snippetMatch), "Café")

        let coffee = NoteSearch.search("COFFEE", in: [a, b, c])
        XCTAssertEqual(coffee.map(\.url), [a])
        let text = try String(contentsOf: a, encoding: .utf8) as NSString
        XCTAssertEqual(text.substring(with: coffee[0].range), "coffee")
    }

    func testOneHitPerLineAndLimits() throws {
        let a = try note("A.md", "foo foo foo\nbar\nfoo\nfoo\n")
        XCTAssertEqual(NoteSearch.search("foo", in: [a]).count, 3)
        XCTAssertEqual(NoteSearch.search("foo", in: [a], perFile: 2).count, 2)
        let b = try note("B.md", "foo")
        XCTAssertEqual(NoteSearch.search("foo", in: [a, b], limit: 1).count, 1)
        XCTAssertTrue(NoteSearch.search("  ", in: [a, b]).isEmpty)
    }

    func testUnsavedTextOverridesDisk() throws {
        let a = try note("A.md", "old words")
        XCTAssertTrue(NoteSearch.search("fresh", in: [a]).isEmpty)
        let hits = NoteSearch.search("fresh", in: [a], overrides: [a: "some fresh words"])
        XCTAssertEqual(hits.first?.range, NSRange(location: 5, length: 5))
    }

    func testLongLinesAreShortenedAroundTheMatch() {
        let line = String(repeating: "word ", count: 60) + "needle" + String(repeating: " tail", count: 60)
        let match = (line as NSString).range(of: "needle")
        let (snippet, range) = NoteSearch.makeSnippet(line, match: match)
        XCTAssertTrue(snippet.hasPrefix("…"))
        XCTAssertTrue(snippet.hasSuffix("…"))
        XCTAssertLessThanOrEqual((snippet as NSString).length, 122)
        XCTAssertEqual((snippet as NSString).substring(with: range), "needle")

        let (short, shortRange) = NoteSearch.makeSnippet("   - [ ] call the needle shop  ", match: NSRange(location: 18, length: 6))
        XCTAssertEqual(short, "- [ ] call the needle shop")
        XCTAssertEqual((short as NSString).substring(with: shortRange), "needle")
    }
}

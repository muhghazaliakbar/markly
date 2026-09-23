import XCTest
@testable import Markly

/// Sync must only ever touch the notes folder, and only the files the user kept checked.
final class GitTests: XCTestCase {
    private var root: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("markly-git-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Notes/Sub"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Sources"), withIntermediateDirectories: true)
        for args in [["init", "-q", "-b", "main"], ["config", "user.name", "Test"], ["config", "user.email", "test@example.com"],
                     ["config", "commit.gpgsign", "false"]] {
            _ = await GitModel.git(args, in: root)
        }
        try write("Notes/Kept.md", "one")
        try write("Notes/Gone.md", "bye")
        try write("Notes/Old name.md", "rename me")
        try write("Sources/App.swift", "let a = 1")
        _ = await GitModel.git(["add", "-A"], in: root)
        _ = await GitModel.git(["commit", "-q", "-m", "Initial"], in: root)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ path: String, _ text: String) throws {
        try text.write(to: root.appendingPathComponent(path), atomically: true, encoding: .utf8)
    }

    private func committedFiles() async -> Set<String> {
        let r = await GitModel.git(["show", "--no-renames", "--name-only", "--format=", "HEAD"], in: root)
        return Set(r.output.split(separator: "\n").map(String.init))
    }

    func testStatusOnlySeesTheNotesFolder() async throws {
        try write("Notes/Kept.md", "two")
        try write("Notes/Sub/[Draft] idea.md", "new")
        try write("Sources/App.swift", "let a = 2")
        try write("Outside.md", "not a note")

        let changes = await GitModel.status(in: root, scope: "Notes/")
        XCTAssertEqual(Set(changes.map(\.path)), ["Notes/Kept.md", "Notes/Sub/[Draft] idea.md"])
        XCTAssertEqual(changes.first { $0.path == "Notes/Kept.md" }?.kind, .modified)
        XCTAssertEqual(changes.first { $0.path.hasSuffix("idea.md") }?.kind, .added)

        let everything = await GitModel.status(in: root, scope: "")
        XCTAssertEqual(everything.count, 4)
    }

    func testCommitIncludesOnlyTheCheckedFiles() async throws {
        try write("Notes/Kept.md", "two")
        try write("Notes/Untitled.md", "")
        try FileManager.default.removeItem(at: root.appendingPathComponent("Notes/Gone.md"))
        try FileManager.default.moveItem(at: root.appendingPathComponent("Notes/Old name.md"),
                                         to: root.appendingPathComponent("Notes/New name.md"))
        _ = await GitModel.git(["add", "-A", "Notes/Old name.md", "Notes/New name.md"], in: root)  // staged rename
        try write("Sources/App.swift", "let a = 2")
        _ = await GitModel.git(["add", "Sources/App.swift"], in: root)  // staged outside the notes

        let changes = await GitModel.status(in: root, scope: "Notes/")
        let rename = try XCTUnwrap(changes.first { $0.kind == .renamed })
        XCTAssertEqual(rename.path, "Notes/New name.md")
        XCTAssertEqual(rename.originalPath, "Notes/Old name.md")

        let chosen = changes.filter { $0.path != "Notes/Untitled.md" }
        let result = await GitModel.commit(chosen, message: "Update notes", in: root)
        XCTAssertEqual(result.status, 0, result.output)

        let committed = await committedFiles()
        XCTAssertEqual(committed, ["Notes/Kept.md", "Notes/Gone.md", "Notes/Old name.md", "Notes/New name.md"])

        // The unchecked note and the staged source file are still waiting, untouched.
        let left = await GitModel.git(["status", "--porcelain"], in: root)
        XCTAssertTrue(left.output.contains("M  Sources/App.swift"), left.output)
        XCTAssertTrue(left.output.contains("?? Notes/Untitled.md"), left.output)
    }

    func testParseStatusHandlesRenamesAndSpaces() {
        let raw = " M a b.md\0R  new.md\0old.md\0?? dir/x.md\0"
        let parsed = GitModel.parseStatus(raw)
        XCTAssertEqual(parsed.map(\.path), ["a b.md", "new.md", "dir/x.md"])
        XCTAssertEqual(parsed[1].originalPath, "old.md")
        XCTAssertEqual(parsed.map(\.kind), [.modified, .renamed, .added])
    }
}

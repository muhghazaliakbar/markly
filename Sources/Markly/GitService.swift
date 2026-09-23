import Foundation

/// A small wrapper around the `git` command line, scoped to the notes folder.
///
/// The notes folder may live inside a bigger repository (a project with a `docs/` folder,
/// or Markly's own repo with its sample notes). Every status, add and commit is limited to
/// that folder with a pathspec, and Sync only commits the files the user reviewed and kept.
@MainActor
final class GitModel: ObservableObject {
    enum State: Equatable {
        case noFolder
        case notRepository
        case repository(branch: String, changes: Int, remote: String?)
    }

    /// One changed file, with its path relative to the repository root.
    struct Change: Identifiable, Hashable, Sendable {
        var path: String
        /// The old path of a rename or copy; it's committed together with `path`.
        var originalPath: String?
        /// The two-letter porcelain code, e.g. " M", "??", "D ", "R ".
        var code: String

        var id: String { path }

        var kind: Kind {
            let x = code.first ?? " ", y = code.last ?? " "
            if code == "??" { return .added }
            if x == "R" || x == "C" { return .renamed }
            if x == "D" || y == "D" { return .deleted }
            if x == "A" { return .added }
            return .modified
        }

        enum Kind { case modified, added, deleted, renamed }
    }

    @Published private(set) var folder: URL?
    @Published private(set) var state: State = .noFolder
    @Published private(set) var busy = false
    @Published private(set) var message: String?
    /// Uncommitted changes inside the notes folder.
    @Published private(set) var changes: [Change] = []
    /// Local commits the next push would publish, or nil when the branch has no upstream.
    @Published private(set) var outgoing: Int?
    /// The notes folder relative to the repository root ("" when they're the same).
    @Published private(set) var scopePrefix = ""

    private var repoRoot: URL?

    func refresh(folder: URL?) {
        self.folder = folder
        guard let folder else { state = .noFolder; changes = []; return }
        Task { await load(folder) }
    }

    private func load(_ folder: URL) async {
        let top = await Self.git(["rev-parse", "--show-toplevel"], in: folder)
        guard top.status == 0 else {
            repoRoot = nil
            changes = []
            outgoing = nil
            state = .notRepository
            return
        }
        let root = URL(fileURLWithPath: top.output.trimmingCharacters(in: .whitespacesAndNewlines))
        let prefix = await Self.git(["rev-parse", "--show-prefix"], in: folder)
        let scope = prefix.output.trimmingCharacters(in: .newlines)
        async let branch = Self.git(["rev-parse", "--abbrev-ref", "HEAD"], in: root)
        async let status = Self.status(in: root, scope: scope)
        async let remote = Self.git(["remote", "get-url", "origin"], in: root)
        async let ahead = Self.git(["rev-list", "--count", "@{upstream}..HEAD"], in: root)
        let (b, found, r, a) = await (branch, status, remote, ahead)
        // A newer refresh (another note, another folder) may have finished first.
        guard folder == self.folder else { return }
        repoRoot = root
        scopePrefix = scope
        changes = found
        outgoing = a.status == 0 ? Int(a.output.trimmingCharacters(in: .whitespacesAndNewlines)) : nil
        let branchName = b.status == 0 ? b.output.trimmingCharacters(in: .whitespacesAndNewlines) : "main"
        let remoteURL = r.status == 0 ? Self.shortRemote(r.output) : nil
        state = .repository(branch: branchName == "HEAD" ? "main" : branchName, changes: found.count, remote: remoteURL)
    }

    func initialize() {
        guard let folder, !busy else { return }
        run {
            let r = await Self.git(["init"], in: folder)
            return r.status == 0 ? "Repository created" : r.lastLine
        }
    }

    /// Commit the chosen changes (nothing else), then pull (rebase) and push when a remote exists.
    func sync(_ selected: [Change]) {
        guard let root = repoRoot, !busy else { return }
        let stamp = Date.now.formatted(date: .abbreviated, time: .shortened)
        run {
            if !selected.isEmpty {
                let result = await Self.commit(selected, message: "Update notes (\(stamp))", in: root)
                if result.status != 0 { return result.lastLine }
            }
            let remote = await Self.git(["remote"], in: root)
            guard !remote.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return selected.isEmpty ? "Nothing to commit" : "Committed locally"
            }
            let pull = await Self.git(["pull", "--rebase", "--autostash"], in: root)
            if pull.status != 0 { return pull.lastLine }
            let push = await Self.git(["push"], in: root)
            if push.status != 0 {
                let retry = await Self.git(["push", "-u", "origin", "HEAD"], in: root)
                if retry.status != 0 { return retry.lastLine }
            }
            return "Synced"
        }
    }

    // MARK: Scoped git

    /// Changed files under `scope` (a path relative to `root`, "" for all of it).
    nonisolated static func status(in root: URL, scope: String) async -> [Change] {
        let r = await git(["--literal-pathspecs", "status", "--porcelain=v1", "-z", "--untracked-files=all",
                           "--", scope.isEmpty ? "." : scope], in: root)
        return r.status == 0 ? parseStatus(r.output) : []
    }

    /// Parses `git status --porcelain=v1 -z`: "XY path\0", with the old path as an extra entry for renames.
    nonisolated static func parseStatus(_ output: String) -> [Change] {
        var entries = output.split(separator: "\0", omittingEmptySubsequences: true).map(String.init)[...]
        var result: [Change] = []
        while let entry = entries.popFirst() {
            guard entry.count > 3 else { continue }
            let code = String(entry.prefix(2))
            let path = String(entry.dropFirst(3))
            var original: String?
            if code.first == "R" || code.first == "C" { original = entries.popFirst() }
            result.append(Change(path: path, originalPath: original, code: code))
        }
        return result
    }

    /// Stages and commits exactly these files. `commit -- <paths>` leaves anything else
    /// that was already staged (outside the notes, or unchecked) out of the commit.
    nonisolated static func commit(_ selected: [Change], message: String, in root: URL) async -> Result {
        let paths = selected.flatMap { [$0.path] + ($0.originalPath.map { [$0] } ?? []) }
        // Only files with unstaged work need `add`; a fully staged path (e.g. a rename's old name)
        // is no longer in the index, and naming it would make `add` fail.
        let unstaged = selected.filter { $0.code.last != " " }.map(\.path)
        if !unstaged.isEmpty {
            let add = await git(["--literal-pathspecs", "add", "-A", "--"] + unstaged, in: root)
            if add.status != 0 { return add }
        }
        return await git(["--literal-pathspecs", "commit", "-m", message, "--"] + paths, in: root)
    }

    private func run(_ work: @escaping () async -> String) {
        busy = true
        message = nil
        Task {
            let result = await work()
            message = result
            busy = false
            if let folder { await load(folder) }
        }
    }

    private static func shortRemote(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["https://", "http://", "ssh://", "git@"] where s.hasPrefix(prefix) { s.removeFirst(prefix.count) }
        if s.hasSuffix(".git") { s.removeLast(4) }
        return s.replacingOccurrences(of: ":", with: "/")
    }

    struct Result: Sendable {
        var status: Int32
        var output: String
        var lastLine: String {
            output.split(separator: "\n").last.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? "git failed"
        }
    }

    nonisolated static func git(_ args: [String], in dir: URL) async -> Result {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                p.arguments = args
                p.currentDirectoryURL = dir
                var env = ProcessInfo.processInfo.environment
                env["GIT_TERMINAL_PROMPT"] = "0"
                p.environment = env
                let pipe = Pipe()
                p.standardOutput = pipe
                p.standardError = pipe
                do {
                    try p.run()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    p.waitUntilExit()
                    continuation.resume(returning: Result(status: p.terminationStatus, output: String(decoding: data, as: UTF8.self)))
                } catch {
                    continuation.resume(returning: Result(status: -1, output: error.localizedDescription))
                }
            }
        }
    }
}

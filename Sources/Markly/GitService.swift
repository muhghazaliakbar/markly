import Foundation

/// A small wrapper around the `git` command line for the folder that holds the current note.
@MainActor
final class GitModel: ObservableObject {
    enum State: Equatable {
        case noFolder
        case notRepository
        case repository(branch: String, changes: Int, remote: String?)
    }

    @Published private(set) var folder: URL?
    @Published private(set) var state: State = .noFolder
    @Published private(set) var busy = false
    @Published private(set) var message: String?
    @Published private(set) var statusText = ""

    private var repoRoot: URL?

    func refresh(folder: URL?) {
        self.folder = folder
        guard let folder else { state = .noFolder; return }
        Task { await load(folder) }
    }

    private func load(_ folder: URL) async {
        let top = await Self.git(["rev-parse", "--show-toplevel"], in: folder)
        guard top.status == 0 else {
            repoRoot = nil
            state = .notRepository
            return
        }
        let root = URL(fileURLWithPath: top.output.trimmingCharacters(in: .whitespacesAndNewlines))
        repoRoot = root
        async let branch = Self.git(["rev-parse", "--abbrev-ref", "HEAD"], in: root)
        async let status = Self.git(["status", "--short", "--branch"], in: root)
        async let remote = Self.git(["remote", "get-url", "origin"], in: root)
        let (b, st, r) = await (branch, status, remote)
        let lines = st.output.split(separator: "\n")
        statusText = st.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let changes = lines.filter { !$0.hasPrefix("##") }.count
        let branchName = b.status == 0 ? b.output.trimmingCharacters(in: .whitespacesAndNewlines) : "main"
        let remoteURL = r.status == 0 ? Self.shortRemote(r.output) : nil
        state = .repository(branch: branchName == "HEAD" ? "main" : branchName, changes: changes, remote: remoteURL)
    }

    func initialize() {
        guard let folder, !busy else { return }
        run {
            let r = await Self.git(["init"], in: folder)
            return r.status == 0 ? "Repository created" : r.lastLine
        }
    }

    /// Commit everything, then pull (rebase) and push when a remote exists.
    func sync() {
        guard let root = repoRoot, !busy else { return }
        run {
            _ = await Self.git(["add", "-A"], in: root)
            let staged = await Self.git(["diff", "--cached", "--quiet"], in: root)
            if staged.status != 0 {
                let stamp = Date.now.formatted(date: .abbreviated, time: .shortened)
                let c = await Self.git(["commit", "-m", "Update notes (\(stamp))"], in: root)
                if c.status != 0 { return c.lastLine }
            }
            let remote = await Self.git(["remote"], in: root)
            guard !remote.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return staged.status != 0 ? "Committed locally" : "Nothing to commit"
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

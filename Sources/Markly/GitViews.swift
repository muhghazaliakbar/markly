import SwiftUI

/// Git lives with the folders in the sidebar: it's an action on the notes, not a setting.
/// A glass button shows the branch state; its popover syncs or shows the status.
struct GitSidebarButton: View {
    @ObservedObject var git: GitModel
    @State private var open = false

    var body: some View {
        Button { open.toggle() } label: {
            Image(systemName: icon)
                .symbolEffect(.rotate, isActive: git.busy)
                .frame(width: 32, height: 32)
                .contentShape(Circle())
                .overlay(alignment: .topTrailing) {
                    if changes > 0 {
                        Text(changes > 99 ? "99+" : "\(changes)")
                            .font(.system(size: 9, weight: .bold).monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .frame(minWidth: 15, minHeight: 15)
                            .background(Capsule().fill(.tint))
                            .offset(x: 4, y: -3)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .animation(GlassStyle.snappy, value: changes)
        .help(help)
        .popover(isPresented: $open, arrowEdge: .top) {
            GitCard(git: git)
        }
    }

    private var changes: Int {
        if case .repository(_, let n, _) = git.state { return n }
        return 0
    }

    private var icon: String {
        switch git.state {
        case .noFolder, .notRepository: "point.3.connected.trianglepath.dotted"
        case .repository: "arrow.triangle.branch"
        }
    }

    private var help: String {
        switch git.state {
        case .noFolder: "Git"
        case .notRepository: "Set up Git for this folder"
        case .repository(let branch, let n, _): n == 0 ? "\(branch): up to date" : "\(branch): \(n) change\(n == 1 ? "" : "s")"
        }
    }
}

/// The Git popover, laid out like the Editor panel: a header, glass cards and one accent action.
/// Sync commits only the checked files inside the notes folder, so nothing is published unseen.
struct GitCard: View {
    @EnvironmentObject var workspace: Workspace
    @ObservedObject var git: GitModel
    @AppStorage(Pref.accent) private var accent = AccentChoice.system
    /// Files the user unchecked. Tracking exclusions keeps newly changed files checked by default.
    @State private var excluded: Set<String> = []

    private var tint: Color { accent.color }
    private var selected: [GitModel.Change] { git.changes.filter { !excluded.contains($0.id) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            GlassEffectContainer(spacing: 6) {
                VStack(spacing: 10) {
                    switch git.state {
                    case .noFolder:
                        note(icon: "folder", text: "Open a note to see its repository.")
                    case .notRepository:
                        note(icon: "point.3.connected.trianglepath.dotted",
                             text: "Track this folder with Git to keep its history and sync it with GitHub or any remote.")
                        action("Initialize Git", icon: "plus", enabled: !git.busy) { git.initialize() }
                    case .repository(let branch, _, let remote):
                        branchCard(branch: branch, remote: remote)
                        if git.changes.isEmpty { clean } else { changesCard }
                        if let n = git.outgoing, n > 0 {
                            Label("Also pushes \(n) earlier commit\(n == 1 ? "" : "s") on \(branch).", systemImage: "arrow.up.circle")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }
                        action(syncTitle, icon: "arrow.triangle.2.circlepath",
                               enabled: !git.busy && (remote != nil || !selected.isEmpty)) {
                            workspace.save()
                            git.sync(selected)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 312)
        .animation(GlassStyle.spring, value: git.changes)
        .animation(GlassStyle.snappy, value: excluded)
        .onChange(of: git.changes) { _, now in excluded.formIntersection(now.map(\.id)) }
    }

    // MARK: Parts

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Git").font(.system(size: 15, weight: .semibold))
                if let message = git.message {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .transition(.opacity)
                }
            }
            Spacer()
            Button { git.refresh(folder: git.folder) } label: {
                Image(systemName: "arrow.clockwise")
                    .symbolEffect(.rotate, isActive: git.busy)
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Circle())
            .foregroundStyle(.secondary)
            .disabled(git.busy)
            .help("Refresh")
        }
        .padding(.leading, 4)
        .animation(GlassStyle.fade, value: git.message)
    }

    private func branchCard(branch: String, remote: String?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(tint.gradient))
            VStack(alignment: .leading, spacing: 1) {
                Text(branch).font(.system(size: 13, weight: .medium))
                Text(remote ?? "No remote · commits stay on this Mac")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: GlassStyle.card)
    }

    private var clean: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            Text("All notes are committed").font(.system(size: 12, weight: .medium))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .glassEffect(.regular, in: GlassStyle.card)
    }

    private var changesCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Changes").font(.system(size: 13, weight: .medium))
                Text("\(selected.count) of \(git.changes.count)")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                Spacer()
                Button(excluded.isEmpty ? "None" : "All") {
                    excluded = excluded.isEmpty ? Set(git.changes.map(\.id)) : []
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint)
                .pointerStyle(.link)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 6)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(git.changes) { change in changeRow(change) }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
            .frame(maxHeight: 196)
            .fixedSize(horizontal: false, vertical: git.changes.count <= 6)
            .scrollIndicators(.automatic)
            .scrollEdgeEffectHidden(true, for: .all)
        }
        .glassEffect(.regular, in: GlassStyle.card)
    }

    private func changeRow(_ change: GitModel.Change) -> some View {
        let on = !excluded.contains(change.id)
        let (folder, name) = split(change.path)
        return Button {
            if on { excluded.insert(change.id) } else { excluded.remove(change.id) }
            GlassStyle.tick()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(on ? AnyShapeStyle(tint) : AnyShapeStyle(.tertiary))
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 0) {
                    Text(name).font(.system(size: 12, weight: .medium)).lineLimit(1).truncationMode(.middle)
                    if !folder.isEmpty {
                        Text(folder).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.head)
                    }
                }
                Spacer(minLength: 4)
                KindBadge(kind: change.kind)
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 34)
            .contentShape(Rectangle())
            .opacity(on ? 1 : 0.6)
        }
        .buttonStyle(ChangeRowStyle())
        .help(change.path)
    }

    private func note(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 18)
            Text(text).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassEffect(.regular, in: GlassStyle.card)
    }

    private func action(_ title: String, icon: String, enabled: Bool, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
                .symbolEffect(.rotate, isActive: git.busy)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .foregroundStyle(.white)
                .contentShape(Capsule())
                .contentTransition(.numericText())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(tint).interactive(), in: Capsule())
        .opacity(enabled ? 1 : 0.45)
        .disabled(!enabled)
    }

    private var syncTitle: String {
        if git.busy { return "Syncing…" }
        switch selected.count {
        case 0: return "Sync"
        case 1: return "Commit 1 File & Sync"
        case let n: return "Commit \(n) Files & Sync"
        }
    }

    /// Splits a repository path into (folder inside the notes, file name).
    private func split(_ path: String) -> (String, String) {
        var inside = path
        if !git.scopePrefix.isEmpty, inside.hasPrefix(git.scopePrefix) { inside.removeFirst(git.scopePrefix.count) }
        let parts = inside.split(separator: "/")
        return (parts.dropLast().joined(separator: "/"), parts.last.map(String.init) ?? inside)
    }
}

/// The one-letter change kind, coloured like Xcode's source control navigator.
private struct KindBadge: View {
    let kind: GitModel.Change.Kind

    var body: some View {
        Text(letter)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .frame(width: 18, height: 18)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(color.opacity(0.15)))
            .help(label)
    }

    private var letter: String {
        switch kind { case .modified: "M"; case .added: "A"; case .deleted: "D"; case .renamed: "R" }
    }
    private var label: String {
        switch kind { case .modified: "Modified"; case .added: "New"; case .deleted: "Deleted"; case .renamed: "Renamed" }
    }
    private var color: Color {
        switch kind { case .modified: .orange; case .added: .green; case .deleted: .red; case .renamed: .blue }
    }
}

/// A list row that highlights on hover and press, like the format bar's buttons.
private struct ChangeRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Row(configuration: configuration)
    }

    private struct Row: View {
        let configuration: Configuration
        @State private var hover = false

        var body: some View {
            configuration.label
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.primary.opacity(configuration.isPressed ? 0.12 : hover ? 0.06 : 0))
                )
                .onHover { hover = $0 }
                .animation(GlassStyle.fade, value: hover)
        }
    }
}

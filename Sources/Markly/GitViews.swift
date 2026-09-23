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
                .frame(width: 300)
                .padding(16)
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

/// Branch state with Sync / Status (or Initialize) actions.
struct GitCard: View {
    @EnvironmentObject var workspace: Workspace
    @ObservedObject var git: GitModel
    @State private var showStatus = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(iconStyle)
                    .frame(width: 22)
                    .symbolEffect(.rotate, isActive: git.busy)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(git.message ?? subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                switch git.state {
                case .noFolder:
                    EmptyView()
                case .notRepository:
                    Button { git.initialize() } label: {
                        Label("Initialize Git", systemImage: "plus").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                case .repository:
                    Button {
                        workspace.save()
                        git.sync()
                    } label: {
                        Label(git.busy ? "Syncing…" : "Sync", systemImage: "arrow.triangle.2.circlepath").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(git.busy)
                    Button { withAnimation(GlassStyle.spring) { showStatus.toggle() } } label: {
                        Label("Status", systemImage: showStatus ? "chevron.up" : "list.bullet").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }
            }
            .controlSize(.large)

            if showStatus, case .repository = git.state {
                ScrollView {
                    Text(git.statusText.isEmpty ? "Clean working tree" : git.statusText)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 160)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var iconName: String {
        switch git.state {
        case .noFolder: "folder"
        case .notRepository: "point.3.connected.trianglepath.dotted"
        case .repository: git.busy ? "arrow.triangle.2.circlepath" : "arrow.triangle.branch"
        }
    }

    private var iconStyle: AnyShapeStyle {
        if case .repository(_, let changes, _) = git.state, changes == 0 { return AnyShapeStyle(.green) }
        return AnyShapeStyle(.secondary)
    }

    private var title: String {
        switch git.state {
        case .noFolder: "Git"
        case .notRepository: "Not a Git repository"
        case .repository(let branch, let changes, _):
            changes == 0 ? "\(branch) · Up to date" : "\(branch) · \(changes) change\(changes == 1 ? "" : "s")"
        }
    }

    private var subtitle: String {
        switch git.state {
        case .noFolder: "Open a note to see its repository."
        case .notRepository: "Track this folder with Git to sync it with GitHub or any remote."
        case .repository(_, _, let remote): remote ?? "No remote yet · commits stay on this Mac"
        }
    }
}

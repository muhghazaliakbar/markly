import Combine
import Sparkle
import SwiftUI

/// In-app updates via Sparkle. The feed is `appcast.xml` on the latest GitHub release (`SUFeedURL`),
/// and every archive is verified against `SUPublicEDKey` before it is installed.
///
/// No request is made until the user agrees: Sparkle asks once on the second launch whether to check
/// automatically (Info.plist leaves `SUEnableAutomaticChecks` unset for that), and the choice can be
/// changed in Settings › Privacy. "Check for Updates…" always works on demand.
@MainActor
final class AppUpdater: ObservableObject {
    static let shared = AppUpdater()

    let controller: SPUStandardUpdaterController
    var updater: SPUUpdater { controller.updater }

    @Published private(set) var canCheck = false
    @Published var checksAutomatically: Bool {
        didSet { if updater.automaticallyChecksForUpdates != checksAutomatically { updater.automaticallyChecksForUpdates = checksAutomatically } }
    }
    @Published var downloadsAutomatically: Bool {
        didSet { if updater.automaticallyDownloadsUpdates != downloadsAutomatically { updater.automaticallyDownloadsUpdates = downloadsAutomatically } }
    }

    private var observers: [AnyCancellable] = []

    private init() {
        // Unbundled runs (`swift run`, tests) have no feed or key; don't start the updater there.
        let bundled = Bundle.main.bundleURL.pathExtension == "app"
        controller = SPUStandardUpdaterController(startingUpdater: bundled, updaterDelegate: nil, userDriverDelegate: nil)
        checksAutomatically = controller.updater.automaticallyChecksForUpdates
        downloadsAutomatically = controller.updater.automaticallyDownloadsUpdates

        // Sparkle changes these itself (the first-run prompt, the update alert's checkbox).
        observers = [
            updater.publisher(for: \.canCheckForUpdates).receive(on: RunLoop.main)
                .sink { [weak self] in self?.canCheck = bundled && $0 },
            updater.publisher(for: \.automaticallyChecksForUpdates).receive(on: RunLoop.main)
                .sink { [weak self] in if self?.checksAutomatically != $0 { self?.checksAutomatically = $0 } },
            updater.publisher(for: \.automaticallyDownloadsUpdates).receive(on: RunLoop.main)
                .sink { [weak self] in if self?.downloadsAutomatically != $0 { self?.downloadsAutomatically = $0 } },
        ]
    }

    func checkForUpdates() { controller.checkForUpdates(nil) }
}

/// "Check for Updates…" in the app menu.
struct CheckForUpdatesCommand: View {
    @ObservedObject var updater: AppUpdater

    var body: some View {
        Button("Check for Updates…") { updater.checkForUpdates() }
            .disabled(!updater.canCheck)
    }
}

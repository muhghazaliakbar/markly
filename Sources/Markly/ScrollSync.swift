import Foundation

/// Carries the editor's reading position to the preview. Deliberately not observable: it never causes a
/// SwiftUI update, and bursts of scroll/caret events are coalesced into one message per run-loop turn.
@MainActor
final class ScrollSync {
    /// Set by the preview while it's on screen.
    var toPreview: ((_ line: Int, _ ratio: Double, _ smooth: Bool) -> Void)?

    /// The last position the editor reported (1-based line, 0…1 from the top of the viewport).
    private(set) var last: (line: Int, ratio: Double)?
    private var pendingSmooth = false
    private var scheduled = false

    var isEnabled: Bool { Pref.bool(Pref.syncPreview, default: true) }

    func editorMoved(line: Int, ratio: Double, smooth: Bool) {
        guard isEnabled else { return }
        last = (line, min(max(ratio, 0), 1))
        pendingSmooth = pendingSmooth || smooth
        guard !scheduled else { return }
        scheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.scheduled = false
            let smooth = self.pendingSmooth
            self.pendingSmooth = false
            if let last = self.last { self.toPreview?(last.line, last.ratio, smooth) }
        }
    }

    /// Re-applies the last position, e.g. after the preview re-rendered or reloaded.
    func resync() {
        guard isEnabled, let last else { return }
        toPreview?(last.line, last.ratio, false)
    }
}

import Foundation
import QuartzCore

/// Carries the editor's reading position to the preview. Deliberately not observable: it never causes a
/// SwiftUI update, and bursts of scroll/caret events are coalesced into one message per run-loop turn.
@MainActor
final class ScrollSync {
    /// Set by the preview while it's on screen.
    var toPreview: ((_ position: Double, _ ratio: Double, _ glide: Bool, _ immediate: Bool) -> Void)?

    /// The last position the editor reported: a fractional 1-based source line, and where it sits in the
    /// viewport (0 = top, 1 = bottom).
    private(set) var last: (position: Double, ratio: Double)?
    private var pendingSmooth = false
    private var scheduled = false

    /// Set by the editor: scroll to a fractional source line (`atTop`/`atEnd` pin the ends of the note).
    var toEditor: ((_ position: Double, _ atTop: Bool, _ atEnd: Bool) -> Void)?

    var isEnabled: Bool { Pref.bool(Pref.syncPreview, default: true) }

    /// Whichever side the reader is scrolling leads; the other only follows. While the preview leads, the
    /// editor's own scroll reports (caused by following) are ignored, so the two never pull on each other.
    private var previewLeadsUntil: CFTimeInterval = 0
    var previewIsLeading: Bool { CACurrentMediaTime() < previewLeadsUntil }

    /// The reader scrolled the preview.
    func previewMoved(position: Double, atTop: Bool, atEnd: Bool) {
        guard isEnabled else { return }
        previewLeadsUntil = CACurrentMediaTime() + 0.4
        last = (position, 0)
        toEditor?(position, atTop, atEnd)
    }

    /// The reader scrolled or clicked in the editor: it takes the lead back at once.
    func editorTookOver() {
        previewLeadsUntil = 0
    }

    func editorMoved(position: Double, ratio: Double, smooth: Bool) {
        guard isEnabled, !previewIsLeading else { return }
        last = (position, min(max(ratio, 0), 1))
        pendingSmooth = pendingSmooth || smooth
        guard !scheduled else { return }
        scheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.scheduled = false
            let smooth = self.pendingSmooth
            self.pendingSmooth = false
            if let last = self.last { self.toPreview?(last.position, last.ratio, smooth, false) }
        }
    }

    /// Re-applies the last position at once, e.g. after the preview re-rendered or reloaded.
    func resync() {
        guard isEnabled, let last else { return }
        toPreview?(last.position, last.ratio, false, true)
    }
}

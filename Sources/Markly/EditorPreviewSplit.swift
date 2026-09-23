import SwiftUI

/// Editor and preview side by side. Unlike `HSplitView`, the split position can be set: the preview opens
/// at exactly half the width. The divider is a hairline with a comfortable drag area and the system's
/// column-resize pointer; double-click it to return to 50/50.
struct EditorPreviewSplit<Editor: View, Preview: View>: View {
    var showsPreview: Bool
    /// Share of the width given to the editor (0…1).
    @Binding var fraction: CGFloat
    @ViewBuilder var editor: () -> Editor
    @ViewBuilder var preview: () -> Preview

    static var minEditor: CGFloat { 320 }
    static var minPreview: CGFloat { 280 }
    private var minEditor: CGFloat { Self.minEditor }
    private var minPreview: CGFloat { Self.minPreview }
    private let hitWidth: CGFloat = 9

    var body: some View {
        GeometryReader { geo in
            let total = geo.size.width
            HStack(spacing: 0) {
                editor()
                    .frame(width: showsPreview ? editorWidth(in: total) : total)
                if showsPreview {
                    divider(total: total)
                    preview()
                        .frame(maxWidth: .infinity)
                }
            }
            .coordinateSpace(.named("split"))
        }
    }

    private func editorWidth(in total: CGFloat) -> CGFloat {
        Self.editorWidth(total: total, fraction: fraction)
    }

    /// Both panes keep their minimum; on a very narrow window the editor gets priority.
    static func editorWidth(total: CGFloat, fraction: CGFloat) -> CGFloat {
        let wanted = (total * fraction).rounded()
        return max(min(wanted, total - minPreview - 1), min(minEditor, total - 1))
    }

    private func divider(total: CGFloat) -> some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1)
            .overlay {
                Color.clear
                    .frame(width: hitWidth)
                    .contentShape(Rectangle())
                    .pointerStyle(.columnResize)
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .named("split"))
                            .onChanged { drag in
                                guard total > 0 else { return }
                                let x = min(max(drag.location.x, minEditor), total - minPreview)
                                fraction = x / total
                            }
                    )
                    .onTapGesture(count: 2) { fraction = 0.5 }
                    .accessibilityElement()
                    .accessibilityLabel("Editor and preview divider")
                    .accessibilityValue("\(Int(fraction * 100)) percent editor")
                    .accessibilityAdjustableAction { direction in
                        fraction = min(max(fraction + (direction == .increment ? 0.05 : -0.05), 0.2), 0.8)
                    }
            }
    }
}

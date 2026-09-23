import AppKit
import SwiftUI

enum GlassStyle {
    static let cardRadius: CGFloat = 22
    static var card: RoundedRectangle { RoundedRectangle(cornerRadius: cardRadius, style: .continuous) }
    static let spring = Animation.spring(response: 0.38, dampingFraction: 0.78)

    static func tick() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
}

/// A row of options on a glass capsule. The selection is a tinted pill that slides between options.
struct GlassSegmented<Value: Hashable>: View {
    struct Option: Identifiable {
        var value: Value
        var icon: String
        var label: String? = nil
        var help: String? = nil
        var id: Value { value }
    }

    let options: [Option]
    @Binding var selection: Value
    var accent: Color

    @Namespace private var pill

    private var hasLabels: Bool { options.contains { $0.label != nil } }
    private var radius: CGFloat { hasLabels ? 18 : 22 }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { option in
                let selected = option.value == selection
                Button {
                    guard !selected else { return }
                    withAnimation(GlassStyle.spring) { selection = option.value }
                    GlassStyle.tick()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: option.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .symbolEffect(.bounce, value: selected)
                        if let label = option.label {
                            Text(label).font(.system(size: 11, weight: .medium))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: hasLabels ? 46 : 34)
                    .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: radius - 4, style: .continuous)
                                .fill(accent.gradient)
                                .shadow(color: accent.opacity(0.35), radius: 8, y: 2)
                                .matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: radius - 4, style: .continuous))
                }
                .buttonStyle(.plain)
                .help(option.help ?? option.label ?? "")
            }
        }
        .padding(4)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// A square glass tile that cycles through a small set of states, shown as dots.
struct GlassTile<Content: View>: View {
    var active: Bool
    var accent: Color
    var count: Int
    var index: Int
    var help: String
    var action: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        Button {
            withAnimation(GlassStyle.spring) { action() }
            GlassStyle.tick()
        } label: {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                content()
                    .foregroundStyle(active ? AnyShapeStyle(.white) : AnyShapeStyle(.primary.opacity(0.75)))
                    .contentTransition(.symbolEffect(.replace))
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    ForEach(0..<count, id: \.self) { i in
                        Circle()
                            .frame(width: 4, height: 4)
                            .opacity(i == index ? 1 : 0.3)
                    }
                }
                .foregroundStyle(active ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 88)
            .contentShape(GlassStyle.card)
        }
        .buttonStyle(.plain)
        .glassEffect(active ? .regular.tint(accent).interactive() : .regular.interactive(), in: GlassStyle.card)
        .help(help)
    }
}

/// A slider drawn as a row of ticks. The current value is a tall accent tick; neighbours shrink and fade
/// with distance, like a lens. Drag or click anywhere on it.
struct TickSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var accent: Color
    var format: (Double) -> String

    private var count: Int { Int(((range.upperBound - range.lowerBound) / step).rounded()) + 1 }
    private var current: Int { Int(((min(max(value, range.lowerBound), range.upperBound) - range.lowerBound) / step).rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(size: 13, weight: .medium))
                Spacer()
                Text(format(value))
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: value))
            }
            GeometryReader { geo in
                let spacing = geo.size.width / CGFloat(max(1, count - 1))
                ZStack {
                    ForEach(0..<count, id: \.self) { i in
                        let d = abs(i - current)
                        Capsule()
                            .fill(i == current ? AnyShapeStyle(accent.gradient) : AnyShapeStyle(Color.primary.opacity(max(0.12, 0.55 - Double(d) * 0.07))))
                            .frame(width: i == current ? 3.5 : 2, height: i == current ? 30 : max(10, 22 - CGFloat(d) * 1.6))
                            .position(x: CGFloat(i) * spacing, y: geo.size.height / 2)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            let i = min(max(Int((g.location.x / spacing).rounded()), 0), count - 1)
                            guard i != current else { return }
                            withAnimation(.snappy(duration: 0.18)) {
                                value = range.lowerBound + Double(i) * step
                            }
                            GlassStyle.tick()
                        }
                )
            }
            .frame(height: 34)
            .padding(.horizontal, 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassEffect(.regular, in: GlassStyle.card)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(format(value))
        .accessibilityAdjustableAction { dir in
            let i = dir == .increment ? min(current + 1, count - 1) : max(current - 1, 0)
            value = range.lowerBound + Double(i) * step
        }
    }
}

/// A capsule toggle chip.
struct GlassChip: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    var accent: Color

    var body: some View {
        Button {
            withAnimation(GlassStyle.spring) { isOn.toggle() }
            GlassStyle.tick()
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(isOn ? .regular.tint(accent).interactive() : .regular.interactive(), in: Capsule())
    }
}

/// A blur of whatever is behind the window (desktop, other apps), like Finder's sidebar.
struct BehindWindowBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        view.material = material
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}

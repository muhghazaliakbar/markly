import AppKit
import SwiftUI

enum GlassStyle {
    static let cardRadius: CGFloat = 22
    static var card: RoundedRectangle { RoundedRectangle(cornerRadius: cardRadius, style: .continuous) }

    static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// Layout changes: panels, sidebar, sections. The system's critically damped "smooth" spring.
    static var spring: Animation { reduceMotion ? .easeInOut(duration: 0.18) : .smooth(duration: 0.34) }
    /// Direct manipulation of controls: pills, tiles, chips.
    static var snappy: Animation { reduceMotion ? .easeInOut(duration: 0.12) : .snappy(duration: 0.24) }
    /// Content swaps such as switching notes.
    static var fade: Animation { .easeInOut(duration: reduceMotion ? 0.1 : 0.18) }

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
                    withAnimation(GlassStyle.snappy) { selection = option.value }
                    GlassStyle.tick()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: option.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .symbolEffect(.bounce.up, options: .speed(1.4), value: selected && !GlassStyle.reduceMotion)
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
            withAnimation(GlassStyle.snappy) { action() }
            GlassStyle.tick()
        } label: {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                content()
                    .foregroundStyle(active ? AnyShapeStyle(.white) : AnyShapeStyle(.primary.opacity(0.75)))
                    .contentTransition(.symbolEffect(.replace.downUp))
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
                            withAnimation(GlassStyle.snappy) {
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
            withAnimation(GlassStyle.snappy) { isOn.toggle() }
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


/// A progressive ("variable") blur like Apple uses in Maps and under toolbars: full strength at the trailing
/// edge, easing smoothly to perfectly clear at the leading edge. No tint, no material — just blur.
///
/// AppKit has no public variable blur, so this uses the same Core Animation `variableBlur` filter the system
/// uses, applied to an `NSVisualEffectView`'s backdrop layer. If that filter isn't available on some future
/// macOS, it falls back to a plain within-window blur masked with the same gradient.
struct ProgressiveBlur: NSViewRepresentable {
    /// Blur radius at the trailing edge, in points.
    var radius: CGFloat = 18

    func makeNSView(context: Context) -> ProgressiveBlurView {
        let view = ProgressiveBlurView()
        view.radius = radius
        return view
    }

    func updateNSView(_ view: ProgressiveBlurView, context: Context) {
        view.radius = radius
    }
}

final class ProgressiveBlurView: NSVisualEffectView {
    var radius: CGFloat = 18 { didSet { if radius != oldValue { apply() } } }
    private var appliedSize: CGSize = .zero

    override init(frame: NSRect) {
        super.init(frame: frame)
        blendingMode = .withinWindow
        state = .active
        material = .fullScreenUI
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }  // purely visual

    override func layout() {
        super.layout()
        if bounds.size != appliedSize { apply() }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        apply()
    }

    // The effect view builds (and sometimes rebuilds) its backdrop layers when it updates its layer.
    override func updateLayer() {
        super.updateLayer()
        apply()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        // The effect view rebuilds its layers on appearance changes; re-apply on the next turn.
        DispatchQueue.main.async { [weak self] in self?.apply() }
    }

    private func apply() {
        appliedSize = bounds.size
        guard bounds.width > 1, bounds.height > 1, let root = layer else { return }
        guard let mask = Self.maskImage() else { return }

        if let blur = Self.variableBlur(radius: radius, mask: mask) {
            // The backdrop layer appears once the effect view has drawn; updateLayer() calls back here.
            guard let backdrop = Self.findBackdrop(in: root) else { return }
            backdrop.filters = [blur]
            // Backdrops render downsampled by default, which shows as a seam where the blur is zero.
            // Full resolution keeps the clear edge pixel-identical to the content beside it.
            backdrop.setValue(1.0, forKey: "scale")
            // Hide the material's tint and grain so only the blur remains.
            for sibling in backdrop.superlayer?.sublayers ?? [] where sibling !== backdrop { sibling.isHidden = true }
            root.mask = nil
        } else {
            // Fallback when the system filter is unavailable: uniform blur, faded out with the same curve.
            let gradient = CAGradientLayer()
            gradient.frame = root.bounds
            gradient.startPoint = CGPoint(x: 0, y: 0.5)
            gradient.endPoint = CGPoint(x: 1, y: 0.5)
            gradient.colors = Self.curve.map { NSColor.black.withAlphaComponent($0).cgColor }
            gradient.locations = Self.curve.indices.map { NSNumber(value: Double($0) / Double(Self.curve.count - 1)) }
            root.mask = gradient
        }
    }

    /// Smootherstep samples: 0 on the left → 1 on the right, no visible banding.
    private static let curve: [CGFloat] = (0...16).map { i in
        let t = Double(i) / 16
        return CGFloat(t * t * t * (t * (t * 6 - 15) + 10))
    }

    private static func maskImage() -> CGImage? {
        let steps = 256
        var pixels = [UInt8](repeating: 0, count: steps * 4)
        for i in 0..<steps {
            let t = Double(i) / Double(steps - 1)
            let e = t * t * t * (t * (t * 6 - 15) + 10)
            pixels[i * 4 + 3] = UInt8((e * 255).rounded())  // black, alpha ramps up to the right
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: steps, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: steps * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    private static func findBackdrop(in layer: CALayer) -> CALayer? {
        if NSStringFromClass(type(of: layer)).contains("Backdrop") { return layer }
        for sub in layer.sublayers ?? [] {
            if let found = findBackdrop(in: sub) { return found }
        }
        return nil
    }

    private static func variableBlur(radius: CGFloat, mask: CGImage) -> NSObject? {
        guard let filterClass = NSClassFromString("CAFilter") as? NSObject.Type else { return nil }
        let selector = NSSelectorFromString("filterWithType:")
        guard filterClass.responds(to: selector),
              let filter = filterClass.perform(selector, with: "variableBlur")?.takeUnretainedValue() as? NSObject
        else { return nil }
        filter.setValue(radius, forKey: "inputRadius")
        filter.setValue(mask, forKey: "inputMaskImage")
        filter.setValue(true, forKey: "inputNormalizeEdges")
        return filter
    }
}

import SwiftUI

/// The floating panel beside the editor. It holds only settings that change how the text looks and
/// behaves while writing, so their effect is visible right next to it. App-wide settings live in the
/// Settings window (⌘,).
struct EditorSettingsPanel: View {
    @Environment(\.openSettings) private var openSettings

    @AppStorage(Pref.font) private var font = FontChoice.sans
    @AppStorage(Pref.fontSize) private var fontSize = 16.0
    @AppStorage(Pref.lineSpacing) private var lineSpacing = 1.4
    @AppStorage(Pref.editorWidth) private var editorWidth = 720.0
    @AppStorage(Pref.syntax) private var syntax = SyntaxVisibility.focused
    @AppStorage(Pref.accent) private var accent = AccentChoice.system
    @AppStorage(Pref.spellCheck) private var spellCheck = true
    @AppStorage(Pref.imagePreview) private var imagePreview = ImagePreview.medium

    private var tint: Color { accent.color }

    var body: some View {
        // The header is fixed so the scroll view never touches the toolbar: macOS gives a scroll view at the
        // toolbar edge its own backing, revealed on hover as a mismatched rectangle.
        VStack(spacing: 0) {
            header
                .padding([.horizontal, .top], 14)
                .padding(.bottom, 12)

            ScrollView {
                GlassEffectContainer(spacing: 6) {
                    VStack(spacing: 12) {
                        tiles

                        GlassSegmented(
                            options: SyntaxVisibility.allCases.map { .init(value: $0, icon: $0.icon, label: $0.label, help: $0.help) },
                            selection: $syntax, accent: tint)

                        TickSlider(title: "Line spacing", value: $lineSpacing, range: 1.0...2.2, step: 0.1, accent: tint) {
                            String(format: "%.1f", $0)
                        }

                        TickSlider(title: "Editor width", value: $editorWidth, range: 480...1360, step: 80, accent: tint) {
                            "\(Int(($0 - 480) / 880 * 60 + 40))%"
                        }

                        GlassChip(title: "Check spelling", icon: "textformat.abc.dottedunderline", isOn: $spellCheck, accent: tint)
                    }
                    .padding([.horizontal, .bottom], 14)
                }
            }
            .scrollIndicators(.never)
            .scrollEdgeEffectHidden(true, for: .all)
        }
        .frame(width: 312)
    }

    private var header: some View {
        HStack {
            Text("Editor")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Button { openSettings() } label: {
                Label("App Settings", systemImage: "gearshape")
                    .labelStyle(.iconOnly)
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Circle())
            .help("App Settings (⌘,)")
        }
        .padding(.leading, 4)
    }

    // MARK: Tiles

    private var tiles: some View {
        HStack(spacing: 10) {
            let size = TextSize.nearest(fontSize)
            GlassTile(active: size != .medium, accent: tint, count: TextSize.allCases.count, index: size.index,
                      help: "Text size: \(size.label)", action: { fontSize = size.next.rawValue }) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("A").font(.system(size: 18 + CGFloat(size.index) * 5, weight: .regular))
                    Image(systemName: "arrow.up").font(.system(size: 11, weight: .bold))
                }
            }
            .contextMenu {
                ForEach(TextSize.allCases) { s in Button(s.label) { fontSize = s.rawValue } }
            }

            GlassTile(active: imagePreview != .off, accent: tint, count: 3, index: max(0, imagePreview.index - 1),
                      help: "Image previews: \(imagePreview.label)", action: { imagePreview = imagePreview.next }) {
                Image(systemName: imagePreview == .off ? "photo.badge.minus" : "photo")
                    .font(.system(size: 22 + CGFloat(max(0, imagePreview.index - 1)) * 4, weight: .regular))
            }
            .contextMenu {
                ForEach(ImagePreview.allCases) { p in Button(p.label) { imagePreview = p } }
            }

            GlassTile(active: font != .sans, accent: tint, count: FontChoice.allCases.count, index: font.index,
                      help: "Typeface: \(font.label)", action: { font = font.next }) {
                Text("Aa").font(.system(size: 30, weight: .regular, design: font.design))
            }
            .contextMenu {
                ForEach(FontChoice.allCases) { f in Button(f.label) { font = f } }
            }
        }
    }
}

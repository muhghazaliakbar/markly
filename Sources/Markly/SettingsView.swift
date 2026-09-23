import SwiftUI

struct SettingsView: View {
    @AppStorage(Pref.font) private var font = FontChoice.sans
    @AppStorage(Pref.fontSize) private var fontSize = 16.0
    @AppStorage(Pref.lineSpacing) private var lineSpacing = 1.4
    @AppStorage(Pref.editorWidth) private var editorWidth = 720.0
    @AppStorage(Pref.syntax) private var syntax = SyntaxVisibility.focused
    @AppStorage(Pref.theme) private var theme = AppTheme.system
    @AppStorage(Pref.accent) private var accent = AccentChoice.system
    @AppStorage(Pref.spellCheck) private var spellCheck = true
    @AppStorage(Pref.showStatusBar) private var showStatusBar = true

    var body: some View {
        Form {
            Section("Typography") {
                Picker("Font", selection: $font) {
                    ForEach(FontChoice.allCases) { Text($0.label).tag($0) }
                }
                LabeledContent("Size") {
                    HStack {
                        Slider(value: $fontSize, in: 11...28, step: 1)
                        Text("\(Int(fontSize)) pt").monospacedDigit().frame(width: 44, alignment: .trailing)
                    }
                }
                LabeledContent("Line spacing") {
                    HStack {
                        Slider(value: $lineSpacing, in: 1.0...2.2, step: 0.05)
                        Text(String(format: "%.2f", lineSpacing)).monospacedDigit().frame(width: 44, alignment: .trailing)
                    }
                }
                LabeledContent("Editor width") {
                    HStack {
                        Slider(value: $editorWidth, in: 480...1400, step: 20)
                        Text("\(Int(editorWidth))").monospacedDigit().frame(width: 44, alignment: .trailing)
                    }
                }
            }
            Section("Markdown") {
                Picker("Syntax markers", selection: $syntax) {
                    ForEach(SyntaxVisibility.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Check spelling while typing", isOn: $spellCheck)
                Toggle("Show word count", isOn: $showStatusBar)
            }
            Section("Appearance") {
                Picker("Theme", selection: $theme) {
                    ForEach(AppTheme.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                LabeledContent("Accent color") {
                    HStack(spacing: 8) {
                        ForEach(AccentChoice.allCases) { choice in
                            Button { accent = choice } label: {
                                Circle()
                                    .fill(choice == .system
                                          ? AnyShapeStyle(AngularGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple, .red], center: .center))
                                          : AnyShapeStyle(choice.color))
                                    .frame(width: 18, height: 18)
                                    .overlay(Circle().strokeBorder(.primary.opacity(accent == choice ? 0.7 : 0), lineWidth: 2).padding(-3))
                            }
                            .buttonStyle(.plain)
                            .help(choice.label)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: theme) { _, t in t.apply() }
    }
}

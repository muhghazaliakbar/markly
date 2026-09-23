# Markly

A calm, native, open-source Markdown editor for macOS. Point it at any folder and it edits your `.md` files in place: no import, no database, no lock-in.

Built with SwiftUI and AppKit (TextKit). No Electron.

## Features

- **Live styling.** Headings, bold, italic, strikethrough, `==highlights==`, links, inline code, code blocks, quotes, tables, math and task lists render as you type.
- **Syntax that gets out of the way.** Markers like `**` and `#` collapse on lines you aren't editing and reappear when the caret moves there. You can also choose to always show them.
- **Folders, not libraries.** Open any folder, browse nested notes in the sidebar, filter by name, and create, rename, reveal or trash files. Changes save automatically to the original file, and files edited elsewhere (git, other editors) reload on their own.
- **Clickable tasks.** Click `[ ]` to check it off. ⌘-click a link to open it; relative `.md` links open inside the editor.
- **Smart lists.** Return continues a list (numbers go up, checkboxes reset), Return on an empty item ends it, and Tab / ⇧Tab indent.
- **Preview pane** (⌥⌘P) with GitHub-style rendering, KaTeX math and syntax highlighting.
- **Export** to HTML or PDF, or print.
- **Typography controls.** Sans, serif or mono font, plus text size, line spacing and editor width.
- **Appearance.** Light, dark or system theme, and the macOS accent color or one of your own.
- **Focus mode** (⇧⌘F) hides everything but the page.

## Keyboard shortcuts

| Action | Shortcut | Action | Shortcut |
| --- | --- | --- | --- |
| Bold | ⌘B | Heading 1–4 | ⌘1–⌘4 |
| Italic | ⌘I | Body text | ⌥⌘0 |
| Strikethrough | ⇧⌘X | Bulleted list | ⇧⌘8 |
| Highlight | ⇧⌘H | Numbered list | ⇧⌘7 |
| Inline code | ⌘E | Task list | ⇧⌘T |
| Link | ⌘K | Quote | ⌘' |
| Code block | ⌥⌘C | Table | ⌥⌘T |
| Preview | ⌥⌘P | Focus mode | ⇧⌘F |
| Bigger / smaller text | ⌘+ / ⌘- | Open folder | ⌘O |

## Building

Requires macOS 14+ and Xcode 15+ (Swift 5.10).

```bash
scripts/build-app.sh            # builds build/Markly.app (universal, ad-hoc signed)
scripts/build-app.sh --install  # also copies it to /Applications
```

For development, open `Package.swift` in Xcode and run the `Markly` scheme, or use `swift run`. Run the tests with `swift test`.

## Project layout

| File | Purpose |
| --- | --- |
| `MarklyApp.swift` | App entry, menus and keyboard shortcuts |
| `Workspace.swift` | Folder scanning, file I/O, autosave, recent folders |
| `EditorView.swift` | SwiftUI ↔ `NSTextView` bridge |
| `MarkdownTextView.swift` | Editor text view (formatting actions, list behavior) and layout manager (block decorations) |
| `MarkdownHighlighter.swift` | Live Markdown styling and syntax hiding |
| `MarkdownRenderer.swift` / `PreviewView.swift` | HTML rendering, preview pane, export and printing |
| `SidebarView.swift`, `ContentView.swift`, `SettingsView.swift` | UI |

HTML rendering uses [swift-markdown](https://github.com/swiftlang/swift-markdown) (GitHub-flavored Markdown). The preview loads KaTeX and highlight.js from jsdelivr, so math and code coloring in the preview need a network connection. The editor itself works fully offline.

## Roadmap ideas

- Git sync and publish
- Pasting and dragging images into a folder next to the note
- Inline image previews in the editor
- Outline / table-of-contents panel
- Full-text search across the folder

Contributions welcome!

## License

MIT

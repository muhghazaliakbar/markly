# Markly

A calm, native, open-source Markdown editor for macOS. Point it at any folder and it edits your `.md` files in place: no import, no database, no lock-in.

Built with SwiftUI and AppKit (TextKit) and Apple's native **Liquid Glass** design. No Electron.

## Features

- **Live styling.** Headings, bold, italic, strikethrough, `==highlights==`, links, inline code, code blocks, quotes, tables, math and task lists render as you type.
- **Syntax that gets out of the way.** Markers like `**` and `#` collapse on lines you aren't editing and reappear when the caret moves there. You can also choose to always show them, or never show them.
- **Folders, not libraries.** Add as many folders as you like to the sidebar, browse nested notes, filter by name (⇧⌘L), and create, rename, reveal or trash files. Jump to the first nine notes with ⌘1–⌘9. Changes save automatically to the original file, and files edited elsewhere (git, other editors) reload on their own.
- **Editor settings panel** (⌥⌘I or the Aa button). A floating Liquid Glass panel for everything that shapes the page you're writing: text size, typeface, inline image previews, syntax visibility, line spacing, editor width and spell checking. The page stays sharp and editable beside it, so changes show up immediately. A progressive blur sits only behind the panel.
- **App settings** (⌘,). A standard Settings window for app-wide preferences: appearance (Light, Dark, Auto), accent color and word count, plus a list of keyboard shortcuts.
- **Inline image previews.** An image on its own line is drawn right in the editor at small, medium or full width.
- **Git sync** from the sidebar. A button shows the branch and number of pending changes; its popover commits everything, pulls (rebase) and pushes in one click, or initializes a new repository.
- **Clickable tasks.** Click `[ ]` to check it off. ⌘-click a link to open it; relative `.md` links open inside the editor.
- **Smart lists.** Return continues a list (numbers go up, checkboxes reset), Return on an empty item ends it, and Tab / ⇧Tab indent.
- **Preview pane** (⌥⌘P) with GitHub-style rendering, KaTeX math and syntax highlighting.
- **Export** to HTML or PDF, or print.
- **Appearance.** Light, dark or system theme, and the macOS accent color or one of your own.
- **Focus mode** (⇧⌘F) hides everything but the page.

## Keyboard shortcuts

| Action | Shortcut | Action | Shortcut |
| --- | --- | --- | --- |
| Bold | ⌘B | Heading 1–4 | ⌥⌘1–⌥⌘4 |
| Italic | ⌘I | Body text | ⌥⌘0 |
| Strikethrough | ⇧⌘X | Bulleted list | ⇧⌘8 |
| Highlight | ⇧⌘H | Numbered list | ⇧⌘7 |
| Inline code | ⌘E | Task list | ⇧⌘T |
| Link | ⌘K | Quote | ⌘' |
| Code block | ⌥⌘C | Table | ⌥⌘T |
| Preview | ⌥⌘P | Focus mode | ⇧⌘F |
| Bigger / smaller text | ⌘+ / ⌘- | Add folder | ⌘O |
| Open note 1–9 | ⌘1–⌘9 | Editor settings | ⌥⌘I |
| App settings | ⌘, | Filter notes | ⇧⌘L |

## Building

Requires macOS 26 (Tahoe) or later and Xcode 26+, because the interface uses the Liquid Glass APIs (`glassEffect`, `GlassEffectContainer`, glass button styles).

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
| `GlassControls.swift` | Liquid Glass building blocks: segmented picker, tiles, tick slider, chips |
| `EditorSettingsPanel.swift` | Floating editor settings panel |
| `AppSettingsView.swift` | Settings window (General, Shortcuts) |
| `GitViews.swift` | Sidebar Git button and sync card |
| `GitService.swift` | Git status and sync through `/usr/bin/git` |
| `ImageStore.swift` | Loads and caches inline image previews |
| `SidebarView.swift`, `ContentView.swift` | Window layout and sidebar |

HTML rendering uses [swift-markdown](https://github.com/swiftlang/swift-markdown) (GitHub-flavored Markdown). The preview loads KaTeX and highlight.js from jsdelivr, so math and code coloring in the preview need a network connection. The editor itself works fully offline.

## Roadmap ideas

- Pasting and dragging images into a folder next to the note
- GitHub sign-in and repository creation
- Outline / table-of-contents panel
- Full-text search across the folder

Contributions welcome!

## License

MIT

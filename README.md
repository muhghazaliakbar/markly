# Markly

A calm, native, open-source Markdown editor for macOS. Point it at any folder and it edits your `.md` files in place: no import, no database, no lock-in.

Built with SwiftUI and AppKit (TextKit) and Apple's native **Liquid Glass** design. No Electron.

## Features

- **Live styling.** Headings, bold, italic, strikethrough, `==highlights==`, links, inline code, code blocks, quotes, tables, math and task lists render as you type.
- **Syntax that gets out of the way.** Markers like `**` and `#` collapse on lines you aren't editing and reappear when the caret moves there. You can also choose to always show them, or never show them.
- **Folders, not libraries.** Add as many folders as you like to the sidebar, browse nested notes, filter by name (⇧⌘L), and create, rename, reveal or trash files. Jump to the first nine notes with ⌘1–⌘9. Changes save automatically to the original file, and files edited elsewhere (git, other editors) reload on their own.
- **Editor settings panel** (⌥⌘I or the Aa button). A floating Liquid Glass panel for everything that shapes the page you're writing: text size, typeface, inline image previews, syntax visibility, line spacing, editor width and spell checking. The page stays sharp and editable beside it, so changes show up immediately. A progressive blur sits only behind the panel.
- **App settings** (⌘,). A standard Settings window with five tabs:
  - **General:** appearance (Light, Dark, Auto), accent color (presets or any custom color), reopen last note, word count, file extension for new notes.
  - **Editor:** smart lists, *typewriter scrolling* (the line you're writing stays centred), *focus on paragraph* (everything else dims), note transition animation.
  - **Privacy:** Markly has no accounts, analytics or tracking. You can turn off the preview's CDN scripts (KaTeX, highlight.js) and loading images from the web; both are enforced with a Content-Security-Policy.
  - **Shortcuts** and **About** (version, open-source notices, copy diagnostics, reset all settings).
- **Inline image previews.** An image on its own line is drawn right in the editor at small, medium or full width.
- **Git sync** from the sidebar. A button shows the branch and number of pending changes; its popover commits everything, pulls (rebase) and pushes in one click, or initializes a new repository.
- **Format bar on selection.** Select text and a Liquid Glass bar appears above it, like Medium's inline editor: bold, italic, strikethrough, highlight, inline code, link (with an inline URL field, prefilled from the clipboard), large/small heading and quote. Active formats are lit; pressing one again removes it. Esc dismisses it; it can be turned off in Settings › Editor.
- **Clickable tasks.** Click `[ ]` to check it off. ⌘-click a link to open it; relative `.md` links open inside the editor.
- **Smart lists.** Return continues a list (numbers go up, checkboxes reset), Return on an empty item ends it, and Tab / ⇧Tab indent.
- **Preview pane** (⌥⌘P) with GitHub-style rendering, KaTeX math and syntax highlighting. It scrolls with the editor in both directions: the result of the line you're editing stays in view, and scrolling the preview moves the editor too (Settings › Editor › Sync preview scrolling).
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

## Download

Grab the latest `Markly-x.y.z.dmg` from [Releases](https://github.com/muhghazaliakbar/markly/releases/latest), open it and drag **Markly** to **Applications**. Requires macOS 26 (Tahoe) or later; the app is universal (Apple silicon and Intel).

If a release is not notarised, macOS blocks it the first time you open it. Go to **System Settings › Privacy & Security** and click **Open Anyway**, or run `xattr -dr com.apple.quarantine /Applications/Markly.app`.

## Getting the code

```bash
git clone git@github.com:muhghazaliakbar/markly.git
cd markly
```

## Building

Requires macOS 26 (Tahoe) or later and Xcode 26+, because the interface uses the Liquid Glass APIs (`glassEffect`, `GlassEffectContainer`, glass button styles).

```bash
scripts/build-app.sh            # builds build/Markly.app (universal, ad-hoc signed)
scripts/build-app.sh --install  # also copies it to /Applications
```

For development, open `Package.swift` in Xcode and run the `Markly` scheme, or use `swift run`. Run the tests with `swift test`.

CI (`.github/workflows/ci.yml`) builds and tests every push and pull request. Pushing a `vX.Y.Z` tag runs `.github/workflows/release.yml`, which builds the universal app, packages it with `scripts/make-dmg.sh` and publishes a GitHub release with the DMG, a zip and checksums.

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

## Contributing

Issues and pull requests are welcome. [AGENTS.md](AGENTS.md) describes the architecture, the design and performance rules, and lessons learned. It's written for human contributors and AI coding agents alike (Claude Code picks it up through [CLAUDE.md](CLAUDE.md) and the project skills in `.claude/skills/`).


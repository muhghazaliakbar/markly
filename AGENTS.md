# Markly — guide for AI agents and contributors

Markly is a native, open-source (MIT) Markdown editor for macOS 26 (Tahoe), written in SwiftUI + AppKit (TextKit 1) with Apple's Liquid Glass design. It edits the Markdown files in the user's own folders in place — no database, no import/export.

Read this before changing anything. It records how the app is put together and the decisions (and mistakes) that shaped it.

## Rules

- **No AI attribution in commits or PRs.** Never add `Co-Authored-By: Claude …`, "Generated with …", or any trailer naming an AI tool. Commits are authored as the repository owner's git identity with plain messages.
- **Native first.** SwiftUI/AppKit controls, Liquid Glass (`glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass)`), SF Symbols, system springs. No custom look where a system one exists. Concentric corners, 4 pt grid.
- **Typing must never wait on the UI.** See *Performance* below; don't regress it.
- **Private by default.** No analytics or telemetry. Network use only for what the user allows in Settings › Privacy (enforced with a Content-Security-Policy) and Git sync.
- **Plain Markdown in plain folders.** Never write app state into the user's notes or folders.
- **Prove fixes.** Reproduce a bug, fix it, and show evidence (a test, a measurement, a screenshot). Several "fixes" in this codebase's history were wrong until measured.

## Build, run, test

Requires macOS 26+ and Xcode 26+ (Swift 6.2 toolchain, Swift 5 language mode).

```bash
swift build                     # debug build
swift test                      # unit tests (XCTest; includes real WKWebView tests)
scripts/build-app.sh            # release, universal, ad-hoc signed → build/Markly.app
scripts/build-app.sh --install  # also copies to /Applications
swift scripts/make-icon.swift   # regenerate Resources/AppIcon.icns (add `preview` for PNGs in $TMPDIR)
```

Preferences live in the `app.markly.Markly` defaults domain.

## Architecture

| File | Responsibility |
| --- | --- |
| `MarklyApp.swift` | App entry, `Window` + `Settings` scenes, menus and keyboard shortcuts (`MarklyCommands`) |
| `Workspace.swift` | Sidebar folders (multi-root), file tree, open/save/autosave, external change reload, `LiveDocument` (throttled text for preview/word count) |
| `ContentView.swift` | Window layout: sidebar, editor/preview split, floating editor panel, status pill, toolbar, click-outside-to-close |
| `EditorView.swift` | `NSViewRepresentable` for the editor; `Coordinator` (highlighting, per-note state/undo, focus dim, typewriter, scroll sync); `EditorContainerView` (note-switch transition) |
| `MarkdownTextView.swift` | The `NSTextView` subclass (formatting actions, smart lists, checkboxes, ⌘-click links, format state) and `MarkdownLayoutManager` (code block / quote / rule / image drawing) |
| `MarkdownHighlighter.swift` | Live styling with syntax hiding; incremental (`limits:`) |
| `MarkdownRenderer.swift` | Markdown → HTML (swift-markdown), block source-line annotations, page template, CSP, and the preview's JavaScript (`__update`, `__swap`, `__syncLine`, `__sourceAt`) |
| `PreviewView.swift` | `WKWebView` preview, script message handler, export/print (`Exporter`) |
| `ScrollSync.swift` | Editor ⇄ preview scroll channel with the leader rule |
| `SelectionToolbar.swift` | Medium-style format bar on selection |
| `EditorSettingsPanel.swift` | Floating per-writing settings panel (⌥⌘I) |
| `AppSettingsView.swift` | Settings window (⌘,): General, Editor, Privacy, Shortcuts, About |
| `EditorPreviewSplit.swift` | 50/50 resizable editor/preview split |
| `GlassControls.swift` | Shared glass controls (`GlassSegmented`, `GlassTile`, `TickSlider`, `GlassChip`), `GlassStyle` animation presets, `BehindWindowBlur`, `ProgressiveBlur` |
| `GitViews.swift`, `GitService.swift` | Sidebar Git button/card and the `git` CLI wrapper |
| `ImageStore.swift` | Inline image loading/cache |
| `Settings.swift` | Preference enums, `Pref` keys (`Pref.all` is used by Reset All Settings), `EditorStyle` |

## Performance rules

- `Workspace.text` is **not** `@Published`. Keystrokes must not invalidate SwiftUI. The preview and word count read `LiveDocument` (throttled ~0.2 s; stats computed off the main thread). External replacements bump `revision`.
- Highlighting is **incremental**: `textDidChange` restyles only edited lines plus old/new caret lines; edits touching ``` / ~~~ / $$ trigger a full pass. `testIncrementalHighlightMatchesFull` guards equivalence. (5,200-line note: 148 ms → 4.8 ms per keystroke.)
- `allowsNonContiguousLayout` is on.
- Never animate the editor's width (it re-wraps every frame). Animate layers/opacity instead.
- Coalesce bursts (slider drags, scroll events) to one update per run-loop turn.

## Animation and style conventions

- Use `GlassStyle.spring` (layout), `.snappy` (controls), `.pop` (transient UI like the format bar), `.fade` (content swaps). All respect Reduce Motion.
- Note switching keeps one editor alive and swaps content under a snapshot (`EditorContainerView.play`); the preview swaps in-page with the same 260 ms `cubic-bezier(0.2, 0.8, 0.2, 1)` curve.
- Floating panels are overlays; they must not change editor layout.

## Hard-won lessons (don't relearn these)

- **SwiftUI `HSplitView` can't set its divider position** → `EditorPreviewSplit`.
- **Scroll views touching the toolbar get a toolbar "scroll pocket" backing that appears on hover**, drawn in a colour that doesn't match the editor. `scrollEdgeEffectHidden` / `.soft` don't remove it. Keep panel scroll views off the toolbar edge (fixed header above them).
- **An `NSHostingView` sized from `fittingSize` before its content appears is 16×16** — the view draws full size but only that square takes clicks. Measure with an off-screen twin (`SelectionToolbarController.measurer`).
- **SwiftUI `.blur` on an `NSViewRepresentable` misplaces NSTextView content**; `CALayer.backgroundFilters` are ignored in modern AppKit. The progressive blur uses the system `variableBlur` CAFilter on an `NSVisualEffectView` backdrop (private API) with a public fallback; set backdrop `scale = 1` or a seam shows.
- **WebKit pauses animations/rAF on hidden pages** — always add timer fallbacks for cleanup (see `__swap`).
- **`window.scrollTo` applies on the next frame**; tests must wait before measuring.
- **NSTextView's `textContainerOrigin` can be overridden** for asymmetric insets; setting `contentInsets` manually disables automatic top insets under the toolbar.
- **Programmatic cursor warps don't generate hover events**, so hover can't be verified by automation.
- **Git is scoped to the notes folder.** Notes often live inside a bigger repo (a project's `docs/`, or this repo's sample notes). Every status/add/commit uses a pathspec for the sidebar root holding the note, and Sync commits only the files the user left checked (`commit -- <paths>` keeps other staged files out). `GitTests` guards this.

## Verifying UI changes on a real Mac

The app runs on the developer's own machine, often while they're working:

- **Ask before bringing Markly to the front or moving the cursor.** Keystrokes typed elsewhere can land in the editor.
- Prefer background runs: `open -g build/Markly.app` plus a temporary env-var hook (mark it `// DEBUG-TEMP`) that logs measurements to stderr (`open --stderr file`). Remove all `DEBUG-TEMP` code before committing.
- Back up and restore preferences **in the same shell command**: `defaults export app.markly.Markly /tmp/p.plist` … `defaults import app.markly.Markly /tmp/p.plist`.
- Tests that edit text use a temporary folder/note (point `roots`/`lastFile` at it, then restore), never the developer's notes.
- Window captures (`screencapture -l <id>`) don't include behind-window blur; region captures (`-R`) do. Under Stage Manager, background windows are thumbnails.

## Commit style

Imperative subject (≤ 72 chars), blank line, body explaining *why*. One logical change per commit. No AI attribution.

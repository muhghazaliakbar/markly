# Roadmap

Where Markly is going. Ticked items have shipped; the rest are ideas, roughly in order. Suggestions are welcome — open an issue or a pull request.

## Shipped

### Editor

- [x] Live Markdown styling with syntax that fades on inactive lines
- [x] Show / Auto / Hide syntax modes
- [x] Smart lists: continue on Return, indent with Tab
- [x] Clickable task checkboxes
- [x] Inline image previews at three sizes
- [x] Format bar on selection with an inline link field
- [x] Typewriter scrolling
- [x] Focus on paragraph
- [x] Per-note caret, scroll position and undo history
- [x] Smooth transitions when switching notes

### Workspace

- [x] Multiple folders in the sidebar
- [x] ⌘1–⌘9 to jump to notes
- [x] Filter notes by name
- [x] Automatic saving and external change detection
- [x] Git status and one-click sync

### Preview and export

- [x] Side-by-side preview with math and code highlighting
- [x] Preview scroll sync with the editor
- [x] Export to HTML and PDF, and printing
- [x] Privacy controls enforced with a Content-Security-Policy

## Next

### Writing

- [ ] Paste or drag an image to save it next to the note and insert it
- [ ] Autocomplete links to other notes when typing `[[`
- [ ] Table editing helpers: add a row or column, tab between cells
- [ ] Smart punctuation that respects code spans
- [ ] Word count goals per note

### Navigation

- [ ] Outline of the note's headings in a popover
- [ ] Full-text search across every folder
- [ ] Backlinks: which notes link to this one
- [ ] Quick open (⌘P style) with fuzzy matching

### Git

- [ ] Scope Sync to the notes folder instead of the whole repository
- [ ] Show a per-note history and restore an older version
- [ ] Conflict resolution when a pull brings in changes to the open note

### Polish

- [ ] Themes for the editor beyond light and dark
- [ ] Custom fonts from the user's font library
- [ ] Localisation, starting with Indonesian
- [ ] Signed and notarised releases with automatic updates

## Principles

Every feature should keep these true:

1. **Your files stay yours.** Plain Markdown in plain folders, readable by any other tool.
2. **Native first.** AppKit and SwiftUI, Liquid Glass, system animations — no web views where a native control will do.
3. **Fast on long notes.** Typing should never wait on the interface.
4. **Private by default.** No accounts, no analytics, no surprise network traffic.

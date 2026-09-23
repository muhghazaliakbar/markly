---
name: app-icon
description: Change or regenerate Markly's app icon (scripts/make-icon.swift → Resources/AppIcon.icns). Use when the icon design, colours or small-size rendering need to change.
---

# App icon

The icon is drawn in code by `scripts/make-icon.swift` (CoreGraphics), so it's reviewable and reproducible.

Current design, "Page #": a slightly tilted white page with a folded corner carrying a coral→pink "#", on a coral→pink superellipse tile. At ≤ 64 px the page is dropped and a bold white "#" sits directly on the tile.

## Workflow

1. Edit `scripts/make-icon.swift`. Keep:
   - the macOS icon grid: 824 pt body centred on a 1024 canvas (`CGRect(x: 100, y: 100, width: 824, height: 824)`),
   - a true superellipse tile (`squircle(in:)`, n ≈ 5), not a rounded rect,
   - a simplified glyph for small sizes (≤ 64 px) so it stays legible at 16 px.
2. Render previews and look at every size on light and dark backgrounds:
   ```bash
   swift scripts/make-icon.swift preview   # writes $TMPDIR/icon-{1024,128,64,32,16}.png and the .icns
   ```
3. Update the sample note image: `sips -Z 512 "$TMPDIR/icon-1024.png" --out "Sample Notes/images/markly.png"`.
4. `scripts/build-app.sh`, then `touch build/Markly.app` and relaunch; if the Dock still shows the old icon, `killall Dock`.

## Caveats

- Don't claim a design is unique. The folded page and "#" are common motifs (it also recalls Slack's old "#" logo); no trademark search has been done. Say so if asked.
- When exploring new directions, render several concepts side by side (large + 64/32/16 px) and let the maintainer choose.

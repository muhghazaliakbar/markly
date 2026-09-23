---
name: run-and-verify
description: Build Markly, launch it and verify a UI or behaviour change on the developer's Mac without stealing focus or losing their notes and preferences. Use after changing anything visible or interactive.
---

# Run and verify Markly

The developer is usually working on this Mac while you test. Nothing you do may type into their apps, move their windows unexpectedly, or change their notes or settings permanently.

## 1. Build and test

```bash
swift build 2>&1 | grep "error:"     # must be empty
swift test 2>&1 | grep -E "error|failed|Executed"
scripts/build-app.sh
```

## 2. Prefer measuring over looking

Add a temporary hook guarded by an environment variable and mark it `// DEBUG-TEMP`:

```swift
if ProcessInfo.processInfo.environment["MARKLY_DEBUG_X"] != nil {  // DEBUG-TEMP
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
        FileHandle.standardError.write("MARKLY value=\(someValue)\n".data(using: .utf8)!)
    }
}
```

Run it in the background, with preferences backed up and restored **in the same shell invocation**:

```bash
defaults export app.markly.Markly "$TMPDIR/markly-prefs-backup.plist"
osascript -e 'quit app "Markly"'; sleep 1.5
# optional: point the app at a throwaway note instead of the developer's notes
T="$TMPDIR/markly-test"; mkdir -p "$T"; printf '# Test\n' > "$T/Note.md"
defaults write app.markly.Markly roots -array "$T"; defaults write app.markly.Markly lastFile "$T/Note.md"
: > "$TMPDIR/log.txt"; open -g --env MARKLY_DEBUG_X=1 --stderr "$TMPDIR/log.txt" build/Markly.app; sleep 5
grep MARKLY "$TMPDIR/log.txt"
osascript -e 'quit app "Markly"'; sleep 1.5
defaults import app.markly.Markly "$TMPDIR/markly-prefs-backup.plist"
open -g build/Markly.app
```

Synthetic clicks can be sent from inside the app with `NSEvent.mouseEvent` + `window.sendEvent` (this is how the format-bar click bug was proven).

## 3. When you must see it

Ask the developer first ("may I bring Markly to the front for ~N seconds?"). Then:

- Window capture: find the window id via `CGWindowListCopyWindowInfo` and `screencapture -x -o -l<id> out.png` (no behind-window blur, and under Stage Manager a background window is only a thumbnail).
- Region capture (`screencapture -x -R x,y,w,h`) shows real compositing including translucency.
- Slow animations down with a temporary duration multiplier to capture mid-transition frames.
- Hover states can't be verified by warping the cursor; ask the developer to check.

## 4. Clean up

```bash
grep -rn "DEBUG-TEMP\|MARKLY_DEBUG" Sources/   # must print nothing
```

Rebuild, relaunch in the background (`open -g`), and report what was verified and what wasn't.

---
name: release
description: Prepare a Markly release — version bump, tests, universal build, Developer ID signing, notarisation and a GitHub release. Use when the maintainer asks to cut or prepare a release.
disable-model-invocation: true
---

# Release checklist

Confirm the version number and whether to publish with the maintainer before any outward-facing step (tagging, pushing, uploading).

1. **Version:** bump `CFBundleShortVersionString` (and `CFBundleVersion`) in `Resources/Info.plist`.
2. **Checks:**
   ```bash
   swift test
   grep -rn "DEBUG-TEMP\|MARKLY_DEBUG" Sources/   # must be empty
   ```
3. **Build:** `scripts/build-app.sh` (universal arm64 + x86_64, ad-hoc signed). Verify with `lipo -archs build/Markly.app/Contents/MacOS/Markly`.
4. **Sign and notarise** (requires the maintainer's Developer ID certificate and a stored notarytool profile — never ask for or handle their credentials yourself):
   ```bash
   codesign --force --deep --options runtime --sign "Developer ID Application: <Name> (<TEAM>)" build/Markly.app
   ditto -c -k --keepParent build/Markly.app build/Markly.zip
   xcrun notarytool submit build/Markly.zip --keychain-profile "<profile>" --wait
   xcrun stapler staple build/Markly.app
   spctl --assess --verbose=2 build/Markly.app
   ```
5. **Manual pass:** the tour note in light and dark mode, Reduce Motion, Reduce Transparency, a folder with many notes, editing a note externally.
6. **Publish** (after the maintainer's go-ahead): tag `vX.Y.Z`, push the tag, create a GitHub release with the zipped app and notes. Release notes and commits carry no AI attribution.

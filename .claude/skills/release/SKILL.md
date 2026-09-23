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
3. **Build locally (optional):** `scripts/build-app.sh && scripts/make-dmg.sh` (universal arm64 + x86_64, ad-hoc signed). Verify with `lipo -archs build/Markly.app/Contents/MacOS/Markly`.
4. **Update feed:** `CFBundleVersion` is set from the CI run number and must keep increasing; Sparkle compares it, not the short version.
5. **Publish** (after the maintainer's go-ahead): commit the version bump, tag `vX.Y.Z` and push the tag. `.github/workflows/release.yml` then tests, builds, packages the DMG and zip, and creates the GitHub release with install notes and generated changelog. It sets the bundle version from the tag.
6. **Signing and notarisation** happen in CI only when these repository secrets exist (the maintainer adds them; never ask for or handle their credentials yourself): `MACOS_CERTIFICATE` (base64 Developer ID Application .p12), `MACOS_CERTIFICATE_PASSWORD`, `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD`. Without them the release is ad-hoc signed and the notes tell users how to allow it. In-app updates additionally need `SPARKLE_PRIVATE_KEY` (the EdDSA key from `generate_keys -x`, matching `SUPublicEDKey` in `Info.plist`); without it the release has no `appcast.xml` and existing installs aren't offered the update.
7. **Manual pass** on the downloaded DMG: install the previous release, then check Markly › Check for Updates… offers and installs this one; the tour note in light and dark mode, Reduce Motion, Reduce Transparency, a folder with many notes, editing a note externally. Release notes and commits carry no AI attribution.

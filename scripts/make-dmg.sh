#!/usr/bin/env bash
# Packages build/Markly.app as build/Markly-<version>.dmg (drag-to-Applications) and .zip.
# Usage: scripts/make-dmg.sh [version]   (run scripts/build-app.sh first)
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Markly.app"
[ -d "$APP" ] || { echo "Missing $APP; run scripts/build-app.sh first" >&2; exit 1; }
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")}"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

DMG="build/Markly-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "Markly $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
ditto -c -k --keepParent "$APP" "build/Markly-$VERSION.zip"
echo "Packaged $DMG and build/Markly-$VERSION.zip"

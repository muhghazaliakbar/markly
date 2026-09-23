#!/usr/bin/env bash
# Builds build/Markly.app (release, ad-hoc signed). Usage: scripts/build-app.sh [--install]
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --arch arm64 --arch x86_64 2>/dev/null || swift build -c release
BIN="$(swift build -c release --show-bin-path 2>/dev/null)/Markly"
[ -f "$BIN" ] || BIN=".build/apple/Products/Release/Markly"

APP="build/Markly.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Markly"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$APP" >/dev/null
echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
  rm -rf /Applications/Markly.app
  cp -R "$APP" /Applications/
  echo "Installed to /Applications/Markly.app"
fi

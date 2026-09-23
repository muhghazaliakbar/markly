#!/usr/bin/env bash
# Builds build/Markly.app (release, ad-hoc signed). Usage: scripts/build-app.sh [--install]
# Set SIGN_IDENTITY to a Developer ID to sign for distribution (hardened runtime + timestamp).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --arch arm64 --arch x86_64 2>/dev/null || swift build -c release
PRODUCTS="$(swift build -c release --show-bin-path 2>/dev/null)"
[ -f "$PRODUCTS/Markly" ] || PRODUCTS=".build/apple/Products/Release"

APP="build/Markly.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$PRODUCTS/Markly" "$APP/Contents/MacOS/Markly"
ditto "$PRODUCTS/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Sign inside-out, as Sparkle documents (no --deep): its helpers first, then the framework, then the app.
IDENTITY="${SIGN_IDENTITY:--}"
FLAGS=(--force --sign "$IDENTITY")
[ "$IDENTITY" = "-" ] || FLAGS+=(--options runtime --timestamp)
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
codesign "${FLAGS[@]}" "$SPARKLE/XPCServices/Installer.xpc"
codesign "${FLAGS[@]}" --preserve-metadata=entitlements "$SPARKLE/XPCServices/Downloader.xpc"
codesign "${FLAGS[@]}" "$SPARKLE/Autoupdate"
codesign "${FLAGS[@]}" "$SPARKLE/Updater.app"
codesign "${FLAGS[@]}" "$APP/Contents/Frameworks/Sparkle.framework"
codesign "${FLAGS[@]}" "$APP"
codesign --verify --deep --strict "$APP"
echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
  rm -rf /Applications/Markly.app
  cp -R "$APP" /Applications/
  echo "Installed to /Applications/Markly.app"
fi

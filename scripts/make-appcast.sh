#!/usr/bin/env bash
# Writes build/appcast.xml, the Sparkle feed for one release, next to build/Markly-<version>.zip.
# Usage: scripts/make-appcast.sh <version> <build> <download-url> [notes.md]
# The EdDSA private key comes from $SPARKLE_PRIVATE_KEY (CI) or, if unset, the login keychain.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$1"; BUILD="$2"; URL="$3"; NOTES="${4:-}"
ZIP="build/Markly-$VERSION.zip"
[ -f "$ZIP" ] || { echo "No $ZIP; run scripts/make-dmg.sh first" >&2; exit 1; }

SIGN_UPDATE=".build/artifacts/sparkle/Sparkle/bin/sign_update"
[ -x "$SIGN_UPDATE" ] || swift package resolve >/dev/null

if [ -n "${SPARKLE_PRIVATE_KEY:-}" ]; then
  # sign_update reads the key from stdin with `--ed-key-file -`.
  ATTRS="$(printf '%s' "$SPARKLE_PRIVATE_KEY" | "$SIGN_UPDATE" --ed-key-file - "$ZIP")"
else
  ATTRS="$("$SIGN_UPDATE" "$ZIP")"
fi
MIN_OS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' Resources/Info.plist)"

DESCRIPTION=""
if [ -n "$NOTES" ] && [ -s "$NOTES" ]; then
  # Sparkle renders Markdown release notes; keep the CDATA section intact.
  DESCRIPTION="      <description sparkle:format=\"markdown\"><![CDATA[$(sed 's/]]>/]] >/g' "$NOTES")]]></description>"
fi

cat > build/appcast.xml <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Markly</title>
    <item>
      <title>Markly $VERSION</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$MIN_OS</sparkle:minimumSystemVersion>
$DESCRIPTION
      <enclosure url="$URL" type="application/octet-stream" $ATTRS />
    </item>
  </channel>
</rss>
XML
xmllint --noout build/appcast.xml
echo "Wrote build/appcast.xml"

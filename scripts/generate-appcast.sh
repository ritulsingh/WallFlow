#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ZIP="${1:-$ROOT/dist/WallFlow-macOS.zip}"
DEST_DIR="$(dirname "$ZIP")"
APPCAST="$DEST_DIR/appcast.xml"

if [[ ! -f "$ZIP" ]]; then
  echo "missing $ZIP" >&2
  exit 1
fi

if [[ -z "${SPARKLE_ED_PRIVATE_KEY:-}" ]]; then
  echo "SPARKLE_ED_PRIVATE_KEY is not set; skipping appcast." >&2
  exit 0
fi

VERSION="$(python3 - <<'PY'
import re, pathlib
text = pathlib.Path("WallFlow.xcodeproj/project.pbxproj").read_text()
print(re.search(r"MARKETING_VERSION = ([0-9.]+);", text).group(1))
PY
)"
BUILD="$(python3 - <<'PY'
import re, pathlib
text = pathlib.Path("WallFlow.xcodeproj/project.pbxproj").read_text()
print(re.search(r"CURRENT_PROJECT_VERSION = ([0-9]+);", text).group(1))
PY
)"

SIG="$(xcrun swift scripts/sign-update.swift "$SPARKLE_ED_PRIVATE_KEY" "$ZIP" | tail -n 1)"
LENGTH="$(stat -f%z "$ZIP" 2>/dev/null || stat -c%s "$ZIP")"
REPO="${GITHUB_REPOSITORY:-ritulsingh/WallFlow}"
TAG="${GITHUB_REF_NAME:-v$VERSION}"
URL="https://github.com/${REPO}/releases/download/${TAG}/WallFlow-macOS.zip"
PUBDATE="$(date -u '+%a, %d %b %Y %H:%M:%S +0000')"

cat > "$APPCAST" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>WallFlow</title>
    <language>en</language>
    <item>
      <title>WallFlow ${VERSION}</title>
      <pubDate>${PUBDATE}</pubDate>
      <sparkle:version>${BUILD}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <enclosure
        url="${URL}"
        sparkle:edSignature="${SIG}"
        length="${LENGTH}"
        type="application/octet-stream" />
    </item>
  </channel>
</rss>
EOF

echo "Wrote $APPCAST"

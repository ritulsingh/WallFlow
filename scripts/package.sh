#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/dist"
DERIVED="$(mktemp -d "${TMPDIR:-/tmp}/wallflow-build.XXXX")"
trap 'rm -rf "$DERIVED"' EXIT

rm -rf "$DEST"
mkdir -p "$DEST"

echo "Building WallFlow (Release)…"
xcodebuild \
  -project "$ROOT/WallFlow.xcodeproj" \
  -scheme WallFlow \
  -configuration Release \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  build

APP="$(find "$DERIVED/Build/Products/Release" -maxdepth 1 -name "WallFlow.app" | head -n 1)"
if [[ -z "$APP" ]]; then
  echo "Release .app was not produced" >&2
  find "$DERIVED/Build/Products" -maxdepth 3 -type d -name "*.app" 2>/dev/null || true
  exit 1
fi

ditto "$APP" "$DEST/WallFlow.app"
ditto -c -k --keepParent "$DEST/WallFlow.app" "$DEST/WallFlow-macOS.zip"

if [[ -n "${SPARKLE_ED_PRIVATE_KEY:-}" ]]; then
  if ! zsh "$ROOT/scripts/generate-appcast.sh" "$DEST/WallFlow-macOS.zip"; then
    echo "Warning: appcast generation failed; releasing zip without Sparkle feed." >&2
  fi
else
  echo "SPARKLE_ED_PRIVATE_KEY unset; skipping appcast." >&2
fi

echo "Packaged $DEST/WallFlow-macOS.zip"
ls -lh "$DEST"

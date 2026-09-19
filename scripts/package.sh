#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/dist"
DERIVED="$DEST/DerivedData"

rm -rf "$DEST"
mkdir -p "$DEST"

xcodebuild \
  -project "$ROOT/LiveWallpaper.xcodeproj" \
  -scheme LiveWallpaper \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  build

APP="$(find "$DERIVED/Build/Products/Release" -maxdepth 1 -name "*.app" | head -n 1)"
if [[ -z "$APP" ]]; then
  echo "Release .app was not produced" >&2
  exit 1
fi

ditto "$APP" "$DEST/WallFlow.app"
ditto -c -k --keepParent "$DEST/WallFlow.app" "$DEST/WallFlow-macOS.zip"

echo "Packaged $DEST/WallFlow-macOS.zip"

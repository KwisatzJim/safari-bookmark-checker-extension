#!/bin/zsh
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$PROJECT_DIR/Build/DevelopmentSigned/Build/Products/Debug/Safari Bookmark Checker.app}"
OUTPUT_DIR="$PROJECT_DIR/Build/Packages"
DMG_PATH="$OUTPUT_DIR/Safari-Bookmark-Checker-development-arm64.dmg"
if [[ ! -d "$APP_PATH" ]]; then
  print -u2 "Build the development app first with Scripts/build-development.sh."
  exit 1
fi
codesign --verify --deep --strict "$APP_PATH"
ARCHITECTURES="$(lipo -archs "$APP_PATH/Contents/MacOS/Safari Bookmark Checker")"
if [[ "$ARCHITECTURES" != "arm64" ]]; then
  print -u2 "This test package is labeled arm64; found: $ARCHITECTURES"
  exit 1
fi
mkdir -p "$OUTPUT_DIR"
STAGING_DIR="$(mktemp -d "$OUTPUT_DIR/staging.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
ditto "$APP_PATH" "$STAGING_DIR/Safari Bookmark Checker.app"
ln -s /Applications "$STAGING_DIR/Applications"
cp "$PROJECT_DIR/Packaging/TESTING.txt" "$STAGING_DIR/READ ME FIRST.txt"
cp "$PROJECT_DIR/LICENSE" "$STAGING_DIR/LICENSE.txt"
hdiutil create -volname "Safari Bookmark Checker Test" -srcfolder "$STAGING_DIR" \
  -format UDZO -ov "$DMG_PATH"
hdiutil verify "$DMG_PATH"
shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"
print "Development test package: $DMG_PATH"

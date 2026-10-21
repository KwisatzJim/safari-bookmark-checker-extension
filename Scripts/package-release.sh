#!/bin/zsh
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
: "${BOOKMARK_CHECKER_SIGNING_IDENTITY:?Set your Developer ID Application identity}"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
APP_PATH="$PROJECT_DIR/Build/DeveloperID/Build/Products/Release/Safari Bookmark Checker.app"
codesign --verify --deep --strict "$APP_PATH"
xcrun stapler validate "$APP_PATH"
[[ "$(lipo -archs "$APP_PATH/Contents/MacOS/Safari Bookmark Checker")" == arm64 ]]
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
[[ "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]
OUTPUT_DIR="$PROJECT_DIR/Build/Packages"
mkdir -p "$OUTPUT_DIR"
DMG_PATH="$OUTPUT_DIR/Safari-Bookmark-Checker-$VERSION-arm64.dmg"
STAGING_DIR="$(mktemp -d "$OUTPUT_DIR/release-staging.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
ditto "$APP_PATH" "$STAGING_DIR/Safari Bookmark Checker.app"
ln -s /Applications "$STAGING_DIR/Applications"
cp "$PROJECT_DIR/Packaging/INSTALLING.txt" "$STAGING_DIR/READ ME FIRST.txt"
cp "$PROJECT_DIR/LICENSE" "$STAGING_DIR/LICENSE.txt"
hdiutil create -volname "Safari Bookmark Checker" -srcfolder "$STAGING_DIR" -format UDZO -ov "$DMG_PATH"
codesign --force --timestamp --sign "$BOOKMARK_CHECKER_SIGNING_IDENTITY" "$DMG_PATH"
hdiutil verify "$DMG_PATH"
codesign --verify --strict "$DMG_PATH"
print "Submit this DMG for notarization, staple its ticket, then create its checksum: $DMG_PATH"

#!/bin/zsh
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
: "${BOOKMARK_CHECKER_TEAM:?Set BOOKMARK_CHECKER_TEAM to your Developer team ID}"
: "${BOOKMARK_CHECKER_SIGNING_IDENTITY:?Set BOOKMARK_CHECKER_SIGNING_IDENTITY to your Developer ID Application identity}"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild \
  -project "$PROJECT_DIR/Xcode/Safari Bookmark Checker/Safari Bookmark Checker.xcodeproj" \
  -scheme "Safari Bookmark Checker" -configuration Release \
  -derivedDataPath "$PROJECT_DIR/Build/DeveloperID" \
  DEVELOPMENT_TEAM="$BOOKMARK_CHECKER_TEAM" CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$BOOKMARK_CHECKER_SIGNING_IDENTITY" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS=--timestamp \
  MACOSX_DEPLOYMENT_TARGET=15.0 ARCHS=arm64 build
APP_PATH="$PROJECT_DIR/Build/DeveloperID/Build/Products/Release/Safari Bookmark Checker.app"
codesign --verify --deep --strict "$APP_PATH"
print "Developer ID build: $APP_PATH"
print "Notarization and stapling are required before distribution."

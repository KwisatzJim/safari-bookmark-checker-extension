#!/bin/zsh
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SIGNING_TEAM="${BOOKMARK_CHECKER_TEAM:-MV65BFBFT7}"
SIGNING_IDENTITY="${BOOKMARK_CHECKER_SIGNING_IDENTITY:-Apple Development}"
SIGNING_STYLE=Automatic
if [[ -n "${BOOKMARK_CHECKER_SIGNING_IDENTITY:-}" ]]; then
  SIGNING_STYLE=Manual
fi
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project "$PROJECT_DIR/Xcode/Safari Bookmark Checker/Safari Bookmark Checker.xcodeproj" \
  -scheme "Safari Bookmark Checker" -configuration Debug \
  -derivedDataPath "$PROJECT_DIR/Build/DevelopmentSigned" \
  DEVELOPMENT_TEAM="$SIGNING_TEAM" CODE_SIGN_STYLE="$SIGNING_STYLE" \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" build

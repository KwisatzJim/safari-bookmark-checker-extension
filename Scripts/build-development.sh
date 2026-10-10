#!/bin/zsh
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SIGNING_TEAM="${BOOKMARK_CHECKER_TEAM:-MV65BFBFT7}"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project "$PROJECT_DIR/Xcode/Safari Bookmark Checker/Safari Bookmark Checker.xcodeproj" \
  -scheme "Safari Bookmark Checker" -configuration Debug \
  -derivedDataPath "$PROJECT_DIR/Build/DevelopmentSigned" \
  DEVELOPMENT_TEAM="$SIGNING_TEAM" CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY="Apple Development" build

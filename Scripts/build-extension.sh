#!/bin/zsh
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project "$PROJECT_DIR/Xcode/Safari Bookmark Checker/Safari Bookmark Checker.xcodeproj" \
  -scheme "Safari Bookmark Checker" -configuration Debug \
  -derivedDataPath "$PROJECT_DIR/Build/Extension" \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual build

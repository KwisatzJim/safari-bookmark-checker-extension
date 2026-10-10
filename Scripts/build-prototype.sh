#!/bin/zsh
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$PROJECT_DIR/Build/Safari Bookmark Reader Prototype.app"
mkdir -p "$APP_DIR/Contents/MacOS"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc \
  -module-cache-path "$PROJECT_DIR/Build/ModuleCache" \
  -external-plugin-path "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins#/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/bin/swift-plugin-server" \
  -parse-as-library "$PROJECT_DIR"/Sources/*.swift \
  -o "$APP_DIR/Contents/MacOS/BookmarkReader" \
  -framework SwiftUI -framework AppKit
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.jimkelley.SafariBookmarkReaderPrototype</string>
<key>CFBundleName</key><string>Safari Bookmark Reader Prototype</string>
<key>CFBundleExecutable</key><string>BookmarkReader</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>0.1</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppleEventsUsageDescription</key><string>Open Safari’s bookmark view so you can manually review, edit, or delete bookmarks.</string>
<key>NSAppTransportSecurity</key><dict>
<key>NSAllowsArbitraryLoads</key><true/>
</dict>
</dict></plist>
PLIST
codesign --force --sign - "$APP_DIR"
print "Built: $APP_DIR"

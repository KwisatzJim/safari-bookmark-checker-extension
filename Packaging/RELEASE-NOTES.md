Safari Bookmark Checker 0.1.1 adds the missing companion app icon, using the existing standalone app artwork. This update is Developer ID signed and Apple notarized for Apple silicon Macs.

### Install

Download `Safari-Bookmark-Checker-0.1.1-arm64.dmg`, open it, and drag the app into Applications. Open the app, grant Full Disk Access in System Settings, quit and reopen it, then enable Safari Bookmark Checker Extension in Safari Settings → Extensions.

If replacing the development build, you may need to remove and re-add the Full Disk Access permission. The DMG includes installation notes and the MIT license. A SHA-256 checksum is provided alongside it.

### Included

- Direct, read-only Safari bookmark scanning without export/import.
- Link checking, redirects, duplicates, search, filtering, and saved results.
- Optional on-device AI page reviews with saved assessments and cancellation.
- Developer ID signatures, hardened runtime, secure timestamps, Apple notarization, and stapled approval tickets.

### Requirements and validation

Requires macOS 15 or later on Apple silicon. AI reviews require macOS 26, Apple Intelligence enabled, and a ready on-device model. Full Disk Access is required. Bookmarks are never edited or deleted by the app.

Version 0.1.0 passed local HTTP fixtures, extraction, response limits, cancellation, saved-review persistence, HEAD-404 fallback, and actual on-device AI checks. This update changes the app icon and version metadata; its built icon resources were verified. The signed Release app was confirmed to launch and read bookmarks locally. App and DMG signatures, notarization tickets, Gatekeeper acceptance, and final package contents/checksum were verified.

The earlier development workflow was tested on a second Mac. A second-Mac installation and persistent Safari extension activation test of this notarized release remains pending. Intel support and Safari profile coverage remain unverified. Sign-in and JavaScript-dependent pages may require manual verification in Safari.

# Changelog

## 0.1.1 — 2026-10-21

- Add the standalone Safari Bookmark Checker icon to the extension companion app so it appears in Finder and the Dock.
- Retain Developer ID signing, hardened runtime, and Apple notarization.

## 0.1.0 — 2026-10-21

- Distribute an Apple silicon Release app and Safari extension signed with Developer ID.
- Enable hardened runtime, secure timestamps, and remove the debugging entitlement.
- Add Apple notarization, stapled approval tickets, signed DMG packaging, and updated installation instructions.
- Add repeatable release build and packaging scripts.

The signed Release app was confirmed to launch and read bookmarks locally. The notarized package passes signature, ticket, and Gatekeeper checks. A second-Mac installation and persistent extension activation test of this notarized release remains pending. Intel compatibility and Safari profile coverage remain unverified.

## 0.1.0-dev.1 — 2026-10-12

First GitHub development prerelease for Apple silicon Macs.

- Read Safari bookmarks directly using the companion app and Full Disk Access.
- Check selected, shown, or all web links; filter, sort, search, and detect duplicates.
- Open bookmarks and redirects in Safari and keep check results across launches.
- Review one or several selected pages using on-device AI, with cancellation and saved reviews.
- Retry HEAD 404 responses with GET before classifying a link as broken.
- Keep the bookmark list visible with a separately scrolling details panel.
- Include an Apple Development-signed DMG, installation notes, MIT license, and SHA-256 checksum.

The development workflow was confirmed working on a second Mac. This release is not Developer ID signed or notarized. AI requires macOS 26 and Apple Intelligence; normal checking targets macOS 15 or later. Intel Macs and Safari profile coverage remain unverified.

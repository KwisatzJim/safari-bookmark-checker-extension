First development prerelease of Safari Bookmark Checker Extension.

### Download and install

For **Apple silicon Macs**, download `Safari-Bookmark-Checker-0.1.0-development-arm64.dmg`. Open the disk image and drag the app into Applications. Open it once, grant Full Disk Access, quit/reopen it, and enable Safari Bookmark Checker Extension in Safari Settings → Extensions.

The DMG includes installation notes and the MIT license. The companion `.sha256` asset lets you verify the download. GitHub also provides the source archives for this tagged version.

### Included

- Read-only direct Safari bookmark scanning; no HTML export/import.
- Selected, filtered, and full link checks; redirects, duplicates, search, folder/status filters, and sorting.
- On-device AI page reviews for one or several selected bookmarks, with saved results and cancellation.
- Persistent link-check results, manual Safari verification, and a scrolling details panel.

### Requirements and limitations

- App targets macOS 15 or later; packaged binary is arm64 only.
- AI review requires macOS 26 or later, Apple Intelligence enabled, and a ready on-device model.
- **Apple Development signed; not Developer ID signed or notarized.** macOS may block this development build, and Safari may require developer settings. If necessary, build from source with your own free development team. Do not disable system-wide security protections.
- Full Disk Access is required because the companion app reads Safari’s saved bookmark file. It never edits or deletes bookmarks.
- Sign-in and JavaScript-dependent pages may need manual verification in Safari. AI assessments do not override link-check status.
- Profile coverage and Intel compatibility remain unverified.

### Validation

The app/extension workflow was confirmed working on a second Mac. HTTP fixtures, page extraction, response limits, cancellation, saved-review persistence, address-change rejection, HEAD-404 fallback, actual on-device model reviews, app signatures, and DMG contents/checksum were checked before publication.

A Developer ID-signed and notarized release will follow when paid developer-account access is available. This release is intentionally marked **prerelease**.

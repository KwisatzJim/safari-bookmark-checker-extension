# Release milestones

## v0.1.0-dev.1

- [x] Read-only scan/check/review workflow confirmed by hands-on testing.
- [x] Saved AI reviews, multiple selection, cancellation, and details layout confirmed.
- [x] Development app and extension confirmed working on a second Mac.
- [x] App, extension, and manifest versions aligned to 0.1.0 (native build 2).
- [x] Local HTTP, extraction, cancellation, persistence, and HEAD-404 checks passed.
- [x] Actual on-device AI lesson and sign-in reviews passed.
- [x] Development build and embedded extension signatures verified.
- [x] Versioned arm64 DMG contents, app signature, and SHA-256 checksum verified.
- [x] README, installation notes, changelog, and MIT license prepared.

GitHub publication uses tag `v0.1.0-dev.1`, marked prerelease, with the development DMG and checksum. This checklist records the development validation; it is not a notarized-release checklist.

## v0.1.0 — 2026-10-21

- [x] Developer ID Application identity verified.
- [x] App and extension signed with hardened runtime, secure timestamps, and no debugging entitlement.
- [x] Signed Release app launch and bookmark reading confirmed locally.
- [x] HTTP fixtures, persistence, HEAD fallback, and actual on-device AI checks passed.
- [x] Apple accepted app submission `42c48341-b6fe-4cfe-abca-590d9ada76b3`.
- [x] App ticket stapled and validated; Gatekeeper accepted as Notarized Developer ID.
- [x] Apple accepted signed DMG submission `da4980b1-7e26-4518-8777-3abdf1fc0e40`.
- [x] DMG ticket stapled and validated; Gatekeeper accepted the DMG.
- [ ] Second-Mac notarized installation and persistent extension activation test.

## Release procedure

1. Create and verify a usable Developer ID Application signing identity.
2. Build a Release configuration with that identity and validate final entitlements, hardened runtime, and secure timestamps.
3. Sign both the app and embedded extension correctly; confirm the app contains no development-only get-task-allow entitlement.
4. Submit the signed artifact to Apple's notarization service and inspect the result.
5. Staple the accepted notarization ticket, build the distribution DMG, and verify Gatekeeper assessment and the download checksum.
6. Test the notarized installation and persistent Safari extension activation on another Mac without relying on developer settings. Confirm Full Disk Access, ordinary checking, and optional AI behavior.
7. Update the README, installation notes, version, changelog, and GitHub release assets/status for the notarized release.

Intel support and Safari profile coverage remain separate, unverified compatibility work. Do not claim support until tested. Preserve bundle identifiers for app preferences continuity; a signing change may require users to grant permissions again.

## v0.1.1 — 2026-10-21

- [x] Reuse the standalone app icon at all ten macOS icon slots.
- [x] Verify compiled AppIcon.icns visually and confirm bundle icon metadata.
- [x] Align native app, extension, and manifest to 0.1.1 (native build 3).
- [x] Developer ID Release build and signature verification passed.
- [x] Apple accepted app submission `cd4d920f-8ba0-4f2c-a226-b21829f71641`.
- [x] Stapled app ticket validated and Gatekeeper accepted the app.

- [x] Apple accepted DMG submission `021f02a2-a4a7-49ef-b3c6-d786bc7db6e3`.
- [x] Stapled DMG ticket, signatures, Gatekeeper, mounted app/icon, and checksum verified.

Second-Mac notarized installation and persistent extension activation remain pending.

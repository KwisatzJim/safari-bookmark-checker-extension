# Safari Bookmark Checker Extension

A read-only Safari bookmark checker for macOS, with a Safari toolbar extension and optional on-device AI page reviews. Scan Safari’s saved bookmarks directly without exporting or importing an HTML file, then review and make any changes yourself in Safari.

The extension opens the companion Mac app, where bookmark reading, checks, and reviews take place. The app never edits or deletes Safari bookmarks.

## Features

- Read bookmark titles, addresses, folder paths, and folder counts; exclude Reading List.
- Check selected bookmarks, filtered results, or all web links, with progress and cancellation.
- Identify HTTP errors, redirects, restricted access, rate limits, and connection problems.
- Find duplicate addresses across folders.
- Search, filter by folder or status, and sort the bookmark list.
- Open original or redirected addresses in Safari, copy addresses, and open Safari’s bookmark view.
- Save link-check results and AI reviews locally across launches.
- Review one or several selected pages using Apple’s on-device language model.

## Requirements and release status

The project targets macOS 15 or later. Local AI review requires macOS 26 or later on a Mac eligible for Apple Intelligence, with Apple Intelligence enabled and its model ready. Ordinary link checking does not require AI.

The current development build has been tested on Apple silicon. Intel compatibility and behavior on a second Mac have not yet been verified. A signed, notarized installer is not available yet; distribution preparation is in progress.

Build from source with Xcode 26 or later installed at `/Applications/Xcode.app`. The validation scripts also require Python 3.

## Set up the app

1. Build the app using the instructions below and open **Safari Bookmark Checker.app** once.
2. In **System Settings → Privacy & Security → Full Disk Access**, add the app and enable access. Quit and reopen the app afterward.
3. In **Safari → Settings → Extensions**, enable **Safari Bookmark Checker Extension**. Restart Safari if the newly built extension has not appeared.
4. Click the toolbar extension and choose **Open Bookmark Checker**, or open the companion app directly.
5. Click **Read Safari Bookmarks**.

Full Disk Access is needed to read `~/Library/Safari/Bookmarks.plist`. macOS may also request Automation permission when **Show Safari Bookmarks** asks Safari to display its bookmark view.

## Check bookmarks

Use **Check Selected**, **Check Shown Web Links**, or **Check All Web Links**. Command-click selects individual bookmarks; Shift-click selects a range. Folder, status, and search filters determine the scope of **Check Shown**, while **Check All** always uses the full web-link collection.

Link checks run in batches of up to six. Cancelling keeps completed results. Refresh rereads Safari’s saved bookmarks and resets the filters. Saved results are restored only when the bookmark identifier and exact address match.

Select a single bookmark to see details, open it in Safari, or inspect a saved AI review. The details panel scrolls independently so the bookmark list stays visible.

### Understand the results

A **Working** result means the HTTP request succeeded; it does not prove that the expected content is present or that you can view content behind sign-in. **Broken** reflects the server’s response to the checker and should be verified in Safari before deleting a bookmark. The checker retries a HEAD 404 with GET because some sites return different responses for those request types.

Restricted access, rate limits, server errors, timeouts, and connection errors appear under **Uncertain**. The checker does not share Safari’s sign-in cookies, so a page that loads in your signed-in browser may respond differently to the app.

Duplicate detection runs locally. It normalizes scheme/host case, default ports, and trailing slashes. Query strings, fragments, and HTTP versus HTTPS remain distinct. Copies in different folders may be intentional.

## Local AI page reviews

Choose **Check → AI Review Selected Page…** for one bookmark, or **AI Review Selected Pages (count)** for a selection. Group reviews run one at a time, show progress and unsuccessful pages, and save each completed review immediately. Cancellation preserves completed reviews and leaves previous reviews intact for unfinished pages.

Reviews can suggest consistent content, a possible error page, a possible content change, or a need for browser verification. They are tentative assessments and do not change the ordinary link-check status.

The review shows its date, HTTP response, destination, and the text used for analysis. **Open in Safari** lets you verify the original bookmark. **Review Again** fetches fresh content and replaces the saved review after success. Opening a saved review does not fetch the page again.

The app reads at most 128 KiB per review and passes at most 2,500 characters of extracted page text to the model. It excludes scripts, styles, navigation, and footers and does not execute JavaScript. Empty pages show **Needs browser verification** and skip AI inference. There is no cloud AI fallback.

## Privacy and access

Bookmark reading and duplicate detection stay on your Mac. Link checks and page reviews contact the selected websites over the internet. AI inference runs on device.

Check results, review dates, assessments, and page excerpts are stored locally in the app’s preferences. Page content is treated as untrusted evidence rather than model instructions.

The companion app is unsandboxed to support direct bookmark-file access with Full Disk Access. The Safari extension is sandboxed and requests no webpage-access or native-messaging permissions. Its popup opens the app through the `safaribookmarkchecker://open` URL scheme.

## Build from source

Open `Xcode/Safari Bookmark Checker/Safari Bookmark Checker.xcodeproj` in Xcode, select the **Safari Bookmark Checker** scheme, and choose your signing team for both targets.

Alternatively, use the development build script with your Apple Development signing team:

```sh
BOOKMARK_CHECKER_TEAM=YOUR_TEAM_ID ./Scripts/build-development.sh
```

The script currently defaults to the original developer’s team. Other contributors should supply their own team identifier. The app is built at:

```text
Build/DevelopmentSigned/Build/Products/Debug/Safari Bookmark Checker.app
```

A development-signed build is intended for local testing. Distribution outside the Mac App Store requires a Developer ID signing workflow and notarization. The older ad-hoc build scripts are retained for experiments; they are not the recommended installation or distribution path.

## Validation

Run the local HTTP fixtures and saved-review checks:

```sh
python3 Tests/run-page-review-validation.py
```

This validates text extraction, redirects, response limits, error-page text, unsupported content, empty pages, cancellation, saved-review serialization, preferences reload, and changed-address rejection. When available, the actual on-device model also reviews a sample lesson and a sign-in page. Model availability is reported when inference cannot run.

`Tests/HeadFallbackValidation.swift` separately covers HEAD 404 followed by GET 200, genuine GET 404, and HTTP 410.

## Project layout

| Folder | Purpose |
| --- | --- |
| `Sources/` | SwiftUI app, bookmark reader, validator, duplicate detection, and AI reviews |
| `Extension/` | Safari Web Extension manifest, popup, and icon |
| `Xcode/` | Companion app and extension targets |
| `Scripts/` | Build and asset-generation helpers |
| `Tests/` | Local validation fixtures |

## Known limitations

- The app reads Safari’s saved bookmark file rather than a supported live-bookmark API. Recent Safari changes may not appear until Safari saves them and you refresh.
- Safari profile coverage has not been verified.
- Sign-in, bot protection, and JavaScript-dependent sites may need manual browser verification.
- Saved AI reviews describe the content fetched at their recorded time; websites may change afterward.
- Installation on another Mac and distribution signing remain to be validated.

Report problems with the macOS/Safari versions, the command used, and the displayed error. Avoid sharing private bookmarks or saved page excerpts in public issues.

## License

Released under the [MIT License](LICENSE). Copyright © 2026 Jim Kelley.

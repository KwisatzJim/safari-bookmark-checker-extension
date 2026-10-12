import AppKit
import SwiftUI

struct FolderSummary: Identifiable {
    let path: String
    var count: Int
    var id: String { path }
}

struct BookmarkEntry: Identifiable {
    let id: String
    let title: String
    let address: String
    let folder: String

    var webURL: URL? {
        guard let url = URL(string: address),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        return url
    }
}

struct SavedBookmarkCheck: Codable {
    let address: String
    let result: BookmarkCheckResult
    let checkedAt: Date
}

struct BookmarkReviewRow: Identifiable {
    let bookmark: BookmarkEntry
    let status: String
    let checkedAt: Date?
    let duplicateCount: Int

    var id: String { bookmark.id }
    var title: String { bookmark.title }
    var address: String { bookmark.address }
    var folder: String { bookmark.folder }
    var checkedSortValue: Date { checkedAt ?? .distantPast }
}

struct BookmarkInventory {
    var webLinks = 0
    var otherLinks = 0
    var folders: [FolderSummary] = []
    var bookmarks: [BookmarkEntry] = []
    var duplicateCounts: [String: Int] = [:]

    static func read() throws -> BookmarkInventory {
        let file = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Safari/Bookmarks.plist")
        let data = try Data(contentsOf: file)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let root = plist as? [String: Any], root["Children"] is [Any] else {
            throw NSError(domain: "BookmarkReader", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Safari’s bookmark file has an unfamiliar structure."])
        }
        var inventory = BookmarkInventory()
        var counts: [String: Int] = [:]
        func visit(_ node: [String: Any], path: [String], isRoot: Bool = false) {
            // Reading List is separate from the bookmark collection.
            if node["Title"] as? String == "com.apple.ReadingList" { return }
            var folderPath = path
            if !isRoot, node["WebBookmarkType"] as? String == "WebBookmarkTypeList" {
                let title = node["Title"] as? String ?? "Untitled Folder"
                folderPath.append(title)
                counts[folderPath.joined(separator: " › "), default: 0] += 0
            }
            if let address = node["URLString"] as? String {
                let scheme = URL(string: address)?.scheme?.lowercased()
                if scheme == "http" || scheme == "https" {
                    inventory.webLinks += 1
                } else {
                    inventory.otherLinks += 1
                }
                let label = folderPath.isEmpty ? "No Folder" : folderPath.joined(separator: " › ")
                counts[label, default: 0] += 1
                let details = node["URIDictionary"] as? [String: Any]
                let title = details?["title"] as? String ?? node["Title"] as? String ?? address
                inventory.bookmarks.append(BookmarkEntry(
                    id: node["WebBookmarkUUID"] as? String ?? UUID().uuidString,
                    title: title.isEmpty ? address : title,
                    address: address,
                    folder: label
                ))
            }
            for child in node["Children"] as? [[String: Any]] ?? [] {
                visit(child, path: folderPath)
            }
        }
        visit(root, path: [], isRoot: true)
        inventory.folders = counts.map { FolderSummary(path: $0.key, count: $0.value) }
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        // Adapt Safari's string identifiers to the existing detector's UUID model.
        let webBookmarks = inventory.bookmarks.compactMap { entry -> (String, Bookmark)? in
            guard let url = entry.webURL else { return nil }
            return (entry.id, Bookmark(title: entry.title, url: url))
        }
        let duplicates = BookmarkDuplicateDetector().duplicateCounts(for: webBookmarks.map { $0.1 })
        for (entryID, bookmark) in webBookmarks {
            if let count = duplicates[bookmark.id] {
                inventory.duplicateCounts[entryID] = count
            }
        }
        return inventory
    }
}

@main
struct BookmarkReaderApp: App {
    var body: some Scene {
        WindowGroup(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Safari Bookmark Checker") {
            ReaderView()
                .onOpenURL { url in
                    guard url.scheme == "safaribookmarkchecker", url.host == "open" else { return }
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    NSApplication.shared.windows.first { $0.isVisible }?.makeKeyAndOrderFront(nil)
                }
        }
        .defaultSize(width: 1100, height: 650)
        .handlesExternalEvents(matching: ["open"])
    }
}

struct ReaderView: View {
    @State private var inventory: BookmarkInventory?
    @State private var errorMessage: String?
    @State private var selectedBookmarkIDs: Set<String> = []
    @State private var showFolders = false
    @State private var openError: String?
    @State private var checkResults: [String: BookmarkCheckResult] = [:]
    @State private var checkedDates: [String: Date] = [:]
    @State private var checkingBookmarkIDs: Set<String> = []
    @State private var checkTask: Task<Void, Never>?
    @State private var completedCheckCount = 0
    @State private var checkTotalCount = 0
    @State private var isCancelling = false
    @State private var checkSummary: String?
    @State private var statusFilter: BookmarkStatusFilter = .all
    @State private var searchText = ""
    @State private var selectedFolder: String?
    @State private var saveError: String?
    @State private var sortOrder = [KeyPathComparator(\BookmarkReviewRow.title)]
    @State private var clipboardMessage: String?
    @State private var bookmarkForAIReview: BookmarkEntry?
    @State private var aiReviews: [String: SavedAIPageReview] = [:]
    @State private var aiReviewTask: Task<Void, Never>?
    @State private var aiReviewCompleted = 0
    @State private var aiReviewTotal = 0
    @State private var aiReviewCurrentTitle = ""
    @State private var aiReviewSummary: String?
    @State private var aiReviewFailures: [String] = []
    private let savedAIReviewsKey = "SafariBookmarkAIReviews.v1"
    private let savedChecksKey = "SafariBookmarkChecks.v1"

    private var isChecking: Bool { checkTask != nil }
    private var isBusy: Bool { isChecking || aiReviewTask != nil }
    private var selectedBookmarks: [BookmarkEntry] {
        tableRows.map(\.bookmark).filter { selectedBookmarkIDs.contains($0.id) }
    }
    private var selectedWebBookmarks: [BookmarkEntry] { selectedBookmarks.filter { $0.webURL != nil } }

    private var visibleBookmarks: [BookmarkEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return (inventory?.bookmarks ?? []).filter { entry in
            if let selectedFolder, entry.folder != selectedFolder { return false }
            guard statusFilter.includes(checkResults[entry.id], isWebLink: entry.webURL != nil,
                                        isDuplicate: inventory?.duplicateCounts[entry.id] != nil) else {
                return false
            }
            return query.isEmpty
                || entry.title.localizedCaseInsensitiveContains(query)
                || entry.address.localizedCaseInsensitiveContains(query)
                || entry.folder.localizedCaseInsensitiveContains(query)
        }
    }

    private var selectedBookmark: BookmarkEntry? {
        selectedBookmarks.count == 1 ? selectedBookmarks.first : nil
    }

    private var tableRows: [BookmarkReviewRow] {
        visibleBookmarks.map { entry in
            BookmarkReviewRow(
                bookmark: entry,
                status: checkingBookmarkIDs.contains(entry.id) ? "Checking…" :
                    checkResults[entry.id]?.label ?? (entry.webURL == nil ? "Not a web link" : "Not checked"),
                checkedAt: checkedDates[entry.id],
                duplicateCount: inventory?.duplicateCounts[entry.id] ?? 0
            )
        }.sorted(using: sortOrder)
    }

    private var shownWebLinkCount: Int {
        visibleBookmarks.filter { $0.webURL != nil }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Safari Bookmark Checker").font(.largeTitle.bold())
            Text("Read-only • Your bookmarks will not be changed.")
                .foregroundStyle(.secondary)
            HStack {
                Button(inventory == nil ? "Read Safari Bookmarks" : "Refresh") { readBookmarks() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isBusy)
                Button("Open Privacy Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("Show Safari Bookmarks") { showSafariBookmarks() }
            }
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).textSelection(.enabled)
                Text("If access was denied, add Safari Bookmark Checker to System Settings → Privacy & Security → Full Disk Access. Then quit and reopen it.")
                Text("Choose the copy of the app you are currently running.").foregroundStyle(.secondary)
            }
            if let saveError {
                Text(saveError).foregroundStyle(.red)
            }
            if let inventory {
                Text("\(inventory.webLinks) web links • \(inventory.otherLinks) other links • \(inventory.folders.count) folder paths")
                    .font(.headline)
                HStack {
                    Picker("View", selection: $showFolders) {
                        Text("Bookmarks").tag(false)
                        Text("Folder Counts").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 300)
                    Spacer()
                    Menu("Check") {
                        Button("Check Selected (\(selectedWebBookmarks.count))") { checkSelectedBookmark() }
                            .disabled(showFolders || selectedWebBookmarks.isEmpty)
                        Button("Check Shown Web Links (\(shownWebLinkCount))") {
                            checkBookmarks(visibleBookmarks)
                        }
                        .disabled(showFolders || shownWebLinkCount == 0)
                        Divider()
                        Button("Check All Web Links (\(inventory.webLinks))") { checkAllBookmarks() }
                            .disabled(inventory.webLinks == 0)
                        Divider()
                        Button("AI Review Selected Page…") { bookmarkForAIReview = selectedBookmark }
                            .disabled(showFolders || selectedBookmark?.webURL == nil)
                        Button("AI Review Selected Pages (\(selectedWebBookmarks.count))") { reviewSelectedPages() }
                            .disabled(showFolders || selectedWebBookmarks.isEmpty)
                    }
                    .disabled(isBusy)
                    .frame(width: 100)
                    Button("Open in Safari") { openSelectedBookmark() }
                        .disabled(showFolders || selectedBookmark?.webURL == nil)
                }
                if aiReviewTask != nil {
                    HStack {
                        ProgressView(value: Double(aiReviewCompleted), total: Double(aiReviewTotal)) {
                            Text("AI reviewed \(aiReviewCompleted) of \(aiReviewTotal) • \(aiReviewCurrentTitle)")
                        }
                        Button("Cancel AI Reviews") { aiReviewTask?.cancel() }
                    }
                }
                if let aiReviewSummary { Text(aiReviewSummary).foregroundStyle(.secondary) }
                if !aiReviewFailures.isEmpty {
                    DisclosureGroup("Pages that could not be reviewed (\(aiReviewFailures.count))") {
                        ScrollView {
                            VStack(alignment: .leading) {
                                ForEach(Array(aiReviewFailures.enumerated()), id: \.offset) { _, failure in
                                    Text(failure).font(.caption).textSelection(.enabled)
                                }
                            }
                        }.frame(maxHeight: 100)
                    }
                }
                if isChecking {
                    HStack(spacing: 16) {
                        ProgressView(value: Double(completedCheckCount), total: Double(checkTotalCount)) {
                            Text(isCancelling ? "Cancelling…" : "Checked \(completedCheckCount) of \(checkTotalCount)")
                        }
                        Button("Cancel", role: .cancel) {
                            isCancelling = true
                            checkTask?.cancel()
                        }
                        .disabled(isCancelling)
                    }
                } else if let checkSummary {
                    Text(checkSummary).font(.caption).foregroundStyle(.secondary)
                }
                if showFolders {
                    Text("Counts are bookmarks directly in each folder, excluding nested folders and Reading List.")
                        .font(.caption).foregroundStyle(.secondary)
                    Table(inventory.folders) {
                        TableColumn("Folder path") { row in Text(row.path) }
                        TableColumn("Bookmarks") { row in Text("\(row.count)") }.width(90)
                    }
                } else {
                    HStack {
                        Picker("Folder", selection: $selectedFolder) {
                            Text("All Folders").tag(nil as String?)
                            ForEach(inventory.folders) { folder in
                                Text("\(folder.path) (\(folder.count))").tag(Optional(folder.path))
                            }
                        }
                        .frame(maxWidth: 600)
                        Spacer()
                    }
                    if selectedFolder != nil {
                        Text("Showing bookmarks directly in this folder; nested folders can be selected separately.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    HStack {
                        Picker("Show", selection: $statusFilter) {
                            ForEach(BookmarkStatusFilter.allCases) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .frame(width: 230)
                        TextField("Search title, address, or folder", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Search bookmarks")
                        if !searchText.isEmpty {
                            Button("Clear") { searchText = "" }
                        }
                        Text("Showing \(visibleBookmarks.count) of \(inventory.bookmarks.count) bookmarks")
                            .foregroundStyle(.secondary)
                    }
                    if statusFilter == .uncertain {
                        Text("Access restrictions, rate limits, server errors, timeouts, and connection errors need manual verification.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if statusFilter == .duplicates {
                        Text("Matching addresses may be intentional in different folders. Review each copy before changing bookmarks in Safari.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Use Command-click or Shift-click to select several bookmarks. Selected: \(selectedBookmarkIDs.count). Select one to view its details.")
                        .font(.caption).foregroundStyle(.secondary)
                    GeometryReader { geometry in
                        VStack(alignment: .leading, spacing: 12) {
                            Table(tableRows, selection: $selectedBookmarkIDs, sortOrder: $sortOrder) {
                                TableColumn("Title", value: \BookmarkReviewRow.title) { row in Text(row.title).help(row.title) }
                                TableColumn("Address", value: \BookmarkReviewRow.address) { row in Text(row.address).help(row.address) }
                                TableColumn("Folder path", value: \BookmarkReviewRow.folder) { row in Text(row.folder).help(row.folder) }
                                TableColumn("Status", value: \BookmarkReviewRow.status) { row in
                                    Text(row.status)
                                }.width(min: 130, ideal: 180)
                                TableColumn("Last Checked", value: \BookmarkReviewRow.checkedSortValue) { row in
                                    if let date = row.checkedAt {
                                        Text(date.formatted(date: .abbreviated, time: .shortened))
                                    } else {
                                        Text("—").foregroundStyle(.secondary)
                                    }
                                }.width(min: 135, ideal: 155)
                                TableColumn("Duplicates", value: \BookmarkReviewRow.duplicateCount) { row in
                                    if row.duplicateCount > 0 {
                                        Text("\(row.duplicateCount) copies").foregroundStyle(.orange)
                                    } else {
                                        Text("—").foregroundStyle(.secondary)
                                    }
                                }.width(85)
                            }
                            if visibleBookmarks.isEmpty {
                                Text("No bookmarks match the current folder, status filter, and search.").foregroundStyle(.secondary)
                            }
                            if let selectedBookmark {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(selectedBookmark.title).font(.headline)
                                        Text(selectedBookmark.address)
                                        Button("Copy Address") {
                                            copyAddress(selectedBookmark.address, label: "Bookmark address")
                                        }
                                        Text(selectedBookmark.folder).foregroundStyle(.secondary)
                                        if let count = inventory.duplicateCounts[selectedBookmark.id] {
                                            Text("\(count) copies of this address across the bookmark collection.")
                                                .foregroundStyle(.orange)
                                        }
                                        if checkingBookmarkIDs.contains(selectedBookmark.id) {
                                            ProgressView("Checking link…")
                                        } else if let result = checkResults[selectedBookmark.id] {
                                            Text(result.label).font(.headline)
                                            if let destination = result.redirectDestination {
                                                Text("Redirects to: \(destination.absoluteString)")
                                                HStack {
                                                    Button("Open Redirect in Safari") { openWebURLInSafari(destination) }
                                                        .disabled(!isWebURL(destination))
                                                    Button("Copy Redirect Address") {
                                                        copyAddress(destination.absoluteString, label: "Redirect address")
                                                    }
                                                }
                                            }
                                            if case .networkError(let detail) = result {
                                                Text(detail).foregroundStyle(.secondary)
                                            }
                                            if let date = checkedDates[selectedBookmark.id] {
                                                Text("Last checked: \(date.formatted(date: .abbreviated, time: .standard))")
                                                    .font(.caption).foregroundStyle(.secondary)
                                            }
                                        }
                                        if let saved = aiReviews[selectedBookmark.id] {
                                            Text("AI review: \(saved.review.label)").font(.headline)
                                            Text("Reviewed: \(saved.reviewedAt.formatted(date: .abbreviated, time: .shortened))")
                                                .font(.caption).foregroundStyle(.secondary)
                                            Button("View Saved AI Review…") { bookmarkForAIReview = selectedBookmark }
                                                .disabled(isBusy)
                                        }
                                        if let clipboardMessage {
                                            Text(clipboardMessage).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                                }
                                .frame(height: min(180, max(0, geometry.size.height * 0.4)))
                            }
                        }
                    }
                }
            } else {
                Spacer()
            }
        }
        .padding(24)
        .frame(minWidth: 900, minHeight: 500)
        .alert("Couldn’t Open Bookmark", isPresented: Binding(
            get: { openError != nil },
            set: { if !$0 { openError = nil } }
        )) {
            Button("OK", role: .cancel) { openError = nil }
        } message: {
            Text(openError ?? "An unknown error occurred.")
        }
        .onDisappear { checkTask?.cancel(); aiReviewTask?.cancel() }
        .sheet(item: $bookmarkForAIReview) { bookmark in
            AIPageReviewView(bookmark: bookmark, savedReview: aiReviews[bookmark.id]) { record in
                aiReviews[bookmark.id] = record
                saveAIReviews()
            }
        }
        .onChange(of: selectedBookmarkIDs) { _, _ in clipboardMessage = nil }
        .onChange(of: visibleBookmarks.map(\.id)) { _, ids in
            selectedBookmarkIDs.formIntersection(Set(ids))
        }
    }

    private func copyAddress(_ address: String, label: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        clipboardMessage = pasteboard.setString(address, forType: .string)
            ? "\(label) copied."
            : "Could not copy the address. Please try again."
    }

    private func showSafariBookmarks() {
        guard let script = NSAppleScript(source: """
            tell application id "com.apple.Safari"
                activate
                show bookmarks
            end tell
            """) else {
            openError = "Could not prepare the command to show Safari’s bookmarks."
            return
        }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "Safari could not show its bookmarks."
            openError = message
        }
    }

    private func openSelectedBookmark() {
        guard let url = selectedBookmark?.webURL else { return }
        openWebURLInSafari(url)
    }

    private func isWebURL(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased()
        return scheme == "http" || scheme == "https"
    }

    private func openWebURLInSafari(_ url: URL) {
        guard isWebURL(url) else { return }
        guard let safari = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") else {
            openError = "Safari could not be found on this Mac."
            return
        }
        NSWorkspace.shared.open([url], withApplicationAt: safari, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error {
                Task { @MainActor in openError = error.localizedDescription }
            }
        }
    }

    private func checkSelectedBookmark() {
        checkBookmarks(selectedWebBookmarks)
    }

    private func checkAllBookmarks() {
        checkBookmarks(inventory?.bookmarks ?? [])
    }

    private func checkBookmarks(_ entries: [BookmarkEntry]) {
        guard !isBusy else { return }
        let targets = entries.compactMap { entry -> (String, Bookmark)? in
            guard let url = entry.webURL else { return nil }
            return (entry.id, Bookmark(title: entry.title, url: url))
        }
        guard !targets.isEmpty else { return }
        completedCheckCount = 0
        checkTotalCount = targets.count
        isCancelling = false
        checkSummary = nil
        checkTask = Task { @MainActor in
            let batchSize = 6
            for start in stride(from: 0, to: targets.count, by: batchSize) {
                guard !Task.isCancelled else { break }
                let batch = targets[start..<min(start + batchSize, targets.count)]
                checkingBookmarkIDs = Set(batch.map { $0.0 })
                await withTaskGroup(of: (String, BookmarkCheckResult).self) { group in
                    for (id, bookmark) in batch {
                        group.addTask {
                            (id, await BookmarkValidator().check(bookmark))
                        }
                    }
                    for await (id, result) in group {
                        guard !Task.isCancelled else {
                            group.cancelAll()
                            break
                        }
                        checkResults[id] = result
                        checkedDates[id] = Date()
                        checkingBookmarkIDs.remove(id)
                        completedCheckCount += 1
                    }
                }
                saveCheckResults()
            }
            checkSummary = Task.isCancelled
                ? "Cancelled after \(completedCheckCount) of \(checkTotalCount). Completed results have been kept."
                : "Finished checking \(completedCheckCount) web links."
            checkingBookmarkIDs = []
            isCancelling = false
            checkTask = nil
        }
    }

    private func saveCheckResults() {
        guard let inventory else { return }
        var records: [String: SavedBookmarkCheck] = [:]
        for entry in inventory.bookmarks {
            guard let result = checkResults[entry.id], let date = checkedDates[entry.id] else { continue }
            records[entry.id] = SavedBookmarkCheck(address: entry.address, result: result, checkedAt: date)
        }
        do {
            let data = try JSONEncoder().encode(records)
            UserDefaults.standard.set(data, forKey: savedChecksKey)
            saveError = nil
        } catch {
            saveError = "Could not save check results: \(error.localizedDescription)"
        }
    }

    private func restoreCheckResults(for inventory: BookmarkInventory) {
        guard let data = UserDefaults.standard.data(forKey: savedChecksKey) else { return }
        do {
            let records = try JSONDecoder().decode([String: SavedBookmarkCheck].self, from: data)
            for entry in inventory.bookmarks {
                guard entry.webURL != nil, let record = records[entry.id],
                      record.address == entry.address else { continue }
                checkResults[entry.id] = record.result
                checkedDates[entry.id] = record.checkedAt
            }
        } catch {
            saveError = "Saved check results could not be read. You can check the links again."
        }
    }

    private func reviewSelectedPages() {
        guard !isBusy else { return }
        let targets = selectedWebBookmarks
        guard !targets.isEmpty else { return }
        aiReviewSummary = nil
        aiReviewFailures = []
        if let unavailable = AIPageReviewer.unavailableMessage {
            aiReviewSummary = unavailable
            return
        }
        aiReviewCompleted = 0
        aiReviewTotal = targets.count
        aiReviewTask = Task { @MainActor in
            var savedCount = 0
            for entry in targets {
                guard !Task.isCancelled else { break }
                aiReviewCurrentTitle = entry.title
                do {
                    guard let url = entry.webURL else { continue }
                    let page = try await PageContentFetcher().fetch(url)
                    try Task.checkCancellation()
                    if #available(macOS 26.0, *) {
                        let review = try await AIPageReviewer.review(page, bookmarkTitle: entry.title)
                        try Task.checkCancellation()
                        aiReviews[entry.id] = SavedAIPageReview(address: entry.address, page: page,
                                                               review: review, reviewedAt: Date())
                        saveAIReviews()
                        savedCount += 1
                    }
                } catch {
                    if Task.isCancelled { break }
                    aiReviewFailures.append("\(entry.title): \(error.localizedDescription)")
                }
                aiReviewCompleted += 1
            }
            aiReviewSummary = "\(Task.isCancelled ? "Cancelled" : "Finished"): \(savedCount) saved AI reviews, \(aiReviewFailures.count) unsuccessful, \(aiReviewTotal - aiReviewCompleted) unprocessed. Select one bookmark to view its saved review."
            aiReviewCurrentTitle = ""
            aiReviewTask = nil
        }
    }

    private func saveAIReviews() {
        do {
            let data = try JSONEncoder().encode(aiReviews)
            UserDefaults.standard.set(data, forKey: savedAIReviewsKey)
        } catch {
            saveError = "Could not save AI reviews: \(error.localizedDescription)"
        }
    }

    private func restoreAIReviews(for inventory: BookmarkInventory) {
        guard let data = UserDefaults.standard.data(forKey: savedAIReviewsKey) else { return }
        do {
            let records = try JSONDecoder().decode([String: SavedAIPageReview].self, from: data)
            for entry in inventory.bookmarks {
                if entry.webURL != nil, let record = records[entry.id], record.matches(address: entry.address) {
                    aiReviews[entry.id] = record
                }
            }
        } catch {
            saveError = "Saved AI reviews could not be read. You can review the pages again."
        }
    }

    private func readBookmarks() {
        guard !isBusy else { return }
        selectedBookmarkIDs = []
        aiReviewSummary = nil
        aiReviewFailures = []
        checkResults = [:]
        aiReviews = [:]
        checkedDates = [:]
        checkSummary = nil
        statusFilter = .all
        searchText = ""
        selectedFolder = nil
        saveError = nil
        do {
            let loadedInventory = try BookmarkInventory.read()
            inventory = loadedInventory
            restoreCheckResults(for: loadedInventory)
            restoreAIReviews(for: loadedInventory)
            errorMessage = nil
        } catch {
            inventory = nil
            errorMessage = "Could not read Safari bookmarks: \(error.localizedDescription)"
        }
    }
}

import Foundation

struct BookmarkDuplicateDetector {
    func duplicateCounts(for bookmarks: [Bookmark]) -> [Bookmark.ID: Int] {
        let groups = Dictionary(grouping: bookmarks) { bookmark in
            normalizedAddress(bookmark.url)
        }

        var counts: [Bookmark.ID: Int] = [:]
        for group in groups.values where group.count > 1 {
            for bookmark in group {
                counts[bookmark.id] = group.count
            }
        }
        return counts
    }

    private func normalizedAddress(_ url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }

        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()

        if (components.scheme == "http" && components.port == 80)
            || (components.scheme == "https" && components.port == 443) {
            components.port = nil
        }

        while components.path.count > 1 && components.path.hasSuffix("/") {
            components.path.removeLast()
        }
        if components.path == "/" {
            components.path = ""
        }

        return components.string ?? url.absoluteString
    }
}

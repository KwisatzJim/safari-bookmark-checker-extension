import Foundation

struct PageContent: Codable, Sendable {
    let originalURL: URL
    let finalURL: URL
    let statusCode: Int
    let title: String
    let text: String
    let wasLimited: Bool
}

enum PageContentError: LocalizedError {
    case invalidAddress, unsupportedContent, unreadableText

    var errorDescription: String? {
        switch self {
        case .invalidAddress: "Only HTTP and HTTPS pages can be reviewed."
        case .unsupportedContent: "This address returned a file or unsupported content type. Open it in Safari for verification."
        case .unreadableText: "The fetched page’s text could not be decoded. Open it in Safari for verification."
        }
    }
}

struct PageContentFetcher: Sendable {
    let maximumBytes: Int
    init(maximumBytes: Int = 131_072) { self.maximumBytes = maximumBytes }

    func fetch(_ url: URL) async throws -> PageContent {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            throw PageContentError.invalidAddress
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = 25
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Safari Bookmark Checker/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,text/plain;q=0.8", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        let mime = http.mimeType?.lowercased() ?? ""
        guard ["text/html", "application/xhtml+xml", "text/plain"].contains(mime) else {
            throw PageContentError.unsupportedContent
        }
        var data = Data()
        var limited = false
        for try await byte in bytes {
            try Task.checkCancellation()
            if data.count >= maximumBytes { limited = true; break }
            data.append(byte)
        }
        try Task.checkCancellation()
        guard let source = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .windowsCP1252)
            ?? String(data: data, encoding: .isoLatin1) else { throw PageContentError.unreadableText }
        let extracted = PageTextExtractor.extract(source, isHTML: mime != "text/plain")
        return PageContent(originalURL: url, finalURL: http.url ?? url, statusCode: http.statusCode,
                           title: String(extracted.title.prefix(180)), text: String(extracted.text.prefix(2500)),
                           wasLimited: limited || extracted.text.count > 2500)
    }
}

struct PageTextExtractor {
    static func extract(_ source: String, isHTML: Bool) -> (title: String, text: String) {
        guard isHTML else { return ("", collapse(source)) }
        let title = capture(source, pattern: #"<title\b[^>]*>(.*?)</title\s*>"#)
        var text = source
        for tag in ["script", "style", "noscript", "svg", "nav", "footer", "head"] {
            text = text.replacingOccurrences(of: "(?is)<\(tag)\\b[^>]*>.*?</\(tag)\\s*>", with: " ",
                                             options: .regularExpression)
            // Remove an unfinished excluded element if the byte limit cut it off.
            text = text.replacingOccurrences(of: "(?is)<\(tag)\\b[^>]*>.*$", with: " ",
                                             options: .regularExpression)
        }
        text = text.replacingOccurrences(of: #"(?s)<!--.*?(?:-->|$)"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"<[^>]*>"#, with: " ", options: .regularExpression)
        return (collapse(decodeEntities(title)), collapse(decodeEntities(text)))
    }

    private static func capture(_ source: String, pattern: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
              let range = Range(match.range(at: 1), in: source) else { return "" }
        return String(source[range])
    }

    private static func collapse(_ text: String) -> String {
        text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeEntities(_ source: String) -> String {
        var text = source
        let regex = try! NSRegularExpression(pattern: #"&#(x[0-9a-fA-F]+|[0-9]+);"#, options: .caseInsensitive)
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let numberRange = Range(match.range(at: 1), in: text),
                  let range = Range(match.range, in: text) else { continue }
            let number = String(text[numberRange])
            let value = number.lowercased().hasPrefix("x") ? UInt32(number.dropFirst(), radix: 16) : UInt32(number)
            if let value, let scalar = UnicodeScalar(value) { text.replaceSubrange(range, with: String(scalar)) }
        }
        for (entity, replacement) in [("&nbsp;", " "), ("&quot;", "\""), ("&apos;", "'"),
                                      ("&lt;", "<"), ("&gt;", ">"), ("&amp;", "&")] {
            text = text.replacingOccurrences(of: entity, with: replacement, options: .caseInsensitive)
        }
        return text
    }
}

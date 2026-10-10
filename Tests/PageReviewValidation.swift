import Foundation

@main
struct PageReviewValidation {
    static func main() async throws {
        let base = CommandLine.arguments[1]
        let sample = """
        <html><head><title>CS50 &amp; C</title><script>
        hidden model instructions
        </script><style>hidden styles</style></head>
        <body><nav>hidden navigation</nav><h1>C programming</h1>
        <p>Learn loops &#38; arrays &#x26; pointers.</p>
        <script>hidden script</script><footer>hidden footer</footer></body></html>
        """
        let extracted = PageTextExtractor.extract(sample, isHTML: true)
        precondition(extracted.title == "CS50 & C")
        precondition(extracted.text == "C programming Learn loops & arrays & pointers.", extracted.text)
        let partial = PageTextExtractor.extract("<h1>Visible</h1><script>unfinished script", isHTML: true)
        precondition(partial.text == "Visible")
        print("PASS readable text extraction, entities, and exclusion of scripts/navigation")
        let page = try await PageContentFetcher().fetch(URL(string: base + "/article")!)
        precondition(page.statusCode == 200 && page.title == "CS50 & C")
        precondition(page.text.contains("loops") && !page.text.contains("hidden"))
        print("PASS bounded GET fetch and extraction")
        let saved = SavedAIPageReview(address: page.originalURL.absoluteString, page: page,
                                     review: AIPageReview(label: "Needs browser verification", explanation: "Test assessment"),
                                     reviewedAt: Date(timeIntervalSince1970: 123456))
        let encoded = try JSONEncoder().encode(["bookmark-id": saved])
        let restored = try JSONDecoder().decode([String: SavedAIPageReview].self, from: encoded)["bookmark-id"]!
        precondition(restored.matches(address: page.originalURL.absoluteString))
        precondition(!restored.matches(address: page.originalURL.absoluteString + "?changed"))
        precondition(restored.page.text == page.text && restored.page.statusCode == page.statusCode)
        precondition(restored.review.explanation == saved.review.explanation && restored.reviewedAt == saved.reviewedAt)
        let suiteName = "BookmarkReviewValidation-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(encoded, forKey: "reviews")
        let reloaded = try JSONDecoder().decode([String: SavedAIPageReview].self,
                                               from: UserDefaults(suiteName: suiteName)!.data(forKey: "reviews")!)
        precondition(reloaded["bookmark-id"]?.page.finalURL == page.finalURL)
        print("PASS saved review round trip, preferences reload, and changed-address rejection")
        let redirected = try await PageContentFetcher().fetch(URL(string: base + "/redirect")!)
        precondition(redirected.finalURL.path == "/article")
        print("PASS redirect destination retained")
        let login = try await PageContentFetcher().fetch(URL(string: base + "/login")!)
        precondition(login.statusCode == 404 && login.text.contains("Sign in"))
        print("PASS error-response text preserved for browser-verification review")
        let large = try await PageContentFetcher(maximumBytes: 1024).fetch(URL(string: base + "/large")!)
        precondition(large.wasLimited && large.text.count <= 1024)
        print("PASS response byte limit")
        do {
            _ = try await PageContentFetcher().fetch(URL(string: base + "/file")!)
            preconditionFailure("Binary file accepted")
        } catch PageContentError.unsupportedContent { print("PASS binary response rejected") }
        let empty = try await PageContentFetcher().fetch(URL(string: base + "/empty")!)
        precondition(empty.statusCode == 200 && empty.text.isEmpty)
        if #available(macOS 26.0, *) {
            let emptyReview = try await AIPageReviewer.review(empty, bookmarkTitle: "Course")
            precondition(emptyReview.label == "Needs browser verification")
            precondition(emptyReview.explanation.contains("AI analysis was skipped"))
        }
        print("PASS empty page preserves HTTP response and requires browser verification")
        let cancelled = Task { try await PageContentFetcher().fetch(URL(string: base + "/slow")!) }
        cancelled.cancel()
        do {
            _ = try await cancelled.value
            preconditionFailure("Cancelled fetch completed")
        } catch { print("PASS cancelled fetch stops") }
        if CommandLine.arguments.contains("--model") {
            if let unavailable = AIPageReviewer.unavailableMessage {
                print("MODEL UNAVAILABLE: \(unavailable)")
            } else if #available(macOS 26.0, *) {
                let review = try await AIPageReviewer.review(page, bookmarkTitle: "CS50 C programming")
                print("MODEL article: \(review.label): \(review.explanation)")
                let loginReview = try await AIPageReviewer.review(login, bookmarkTitle: "CS50 Week 1 C")
                print("MODEL login: \(loginReview.label): \(loginReview.explanation)")
                precondition(loginReview.label == "Needs browser verification", "Login page must not become a deletion verdict")
            }
        }
    }
}

import SwiftUI
import AppKit

struct AIPageReviewView: View {
    let bookmark: BookmarkEntry
    let savedReview: SavedAIPageReview?
    let onSave: (SavedAIPageReview) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var page: PageContent?
    @State private var review: AIPageReview?
    @State private var message: String?
    @State private var isReviewing = true
    @State private var openError: String?
    @State private var reviewedAt: Date?
    @State private var reviewAttempt = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Review Selected Page").font(.title.bold())
            Text(bookmark.title).font(.headline)
            Text(bookmark.address).font(.caption).textSelection(.enabled)
            Text("The webpage is fetched over the internet. Analysis uses Apple’s on-device model; no cloud AI is used.")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if isReviewing { ProgressView(page == nil ? "Fetching page text…" : "Reviewing locally…") }
                    if let page {
                        Text("Fetched response: HTTP \(page.statusCode)").font(.headline)
                        if page.finalURL != page.originalURL {
                            Text("Final address: \(page.finalURL.absoluteString)")
                        }
                        if !page.title.isEmpty { Text("Page title: \(page.title)") }
                    }
                    if let reviewedAt {
                        Text("Saved review from \(reviewedAt.formatted(date: .abbreviated, time: .standard)). Page content may have changed since then.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let review {
                        Text(review.label).font(.headline)
                        Text(review.explanation)
                    }
                    if let message { Text(message).foregroundStyle(.secondary) }
                    if let page, !page.text.isEmpty {
                        DisclosureGroup("Page text used for this review") {
                            Text(page.text).font(.caption).padding(.top, 6)
                        }
                        if page.wasLimited { Text("Only a limited excerpt was reviewed.").font(.caption) }
                    }
                    Text("Verify in Safari before changing a bookmark. This fetch does not share Safari’s sign-in cookies or run page JavaScript. The normal link status is unchanged.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            }
            HStack {
                Button("Open in Safari") { openInSafari() }
                    .disabled(bookmark.webURL == nil)
                Button("Review Again") {
                    isReviewing = true
                    page = nil
                    review = nil
                    message = nil
                    reviewedAt = nil
                    reviewAttempt += 1
                }.disabled(isReviewing)
                Spacer()
                Button(isReviewing ? "Cancel" : "Close") { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 680, height: 540)
        .task(id: reviewAttempt) {
            if reviewAttempt == 0, let savedReview, savedReview.matches(address: bookmark.address) {
                page = savedReview.page
                review = savedReview.review
                reviewedAt = savedReview.reviewedAt
                isReviewing = false
            } else {
                await runReview()
            }
        }
        .alert("Could not open Safari", isPresented: Binding(
            get: { openError != nil }, set: { if !$0 { openError = nil } }
        )) {
            Button("OK") { openError = nil }
        } message: {
            Text(openError ?? "")
        }
    }

    private func openInSafari() {
        guard let url = bookmark.webURL else { return }
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

    @MainActor
    private func runReview() async {
        defer { isReviewing = false }
        if let unavailable = AIPageReviewer.unavailableMessage {
            message = unavailable
            return
        }
        guard let url = bookmark.webURL else { return }
        do {
            let fetched = try await PageContentFetcher().fetch(url)
            try Task.checkCancellation()
            page = fetched
            if #available(macOS 26.0, *) {
                let assessment = try await AIPageReviewer.review(fetched, bookmarkTitle: bookmark.title)
                try Task.checkCancellation()
                review = assessment
                let date = Date()
                reviewedAt = date
                onSave(SavedAIPageReview(address: bookmark.address, page: fetched,
                                        review: assessment, reviewedAt: date))
            }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            message = "Review could not finish: \(error.localizedDescription)"
        }
    }
}

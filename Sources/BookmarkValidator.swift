import Foundation

struct BookmarkValidator: Sendable {
    func check(_ bookmark: Bookmark) async -> BookmarkCheckResult {
        do {
            var response = try await request(bookmark.url, method: "HEAD")

            // Some sites return 404 for HEAD even when a normal GET succeeds.
            if [400, 403, 404, 405, 501].contains(response.statusCode) {
                response = try await request(bookmark.url, method: "GET")
            }

            return classify(response, originalURL: bookmark.url)
        } catch let error as URLError where error.code == .timedOut {
            return .timedOut
        } catch let error as URLError {
            return .networkError(error.localizedDescription)
        } catch {
            return .networkError(error.localizedDescription)
        }
    }

    private func request(_ url: URL, method: String) async throws -> HTTPResult {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Safari Bookmark Checker/1.0", forHTTPHeaderField: "User-Agent")

        if method == "GET" {
            request.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        }

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        return HTTPResult(statusCode: httpResponse.statusCode, finalURL: httpResponse.url ?? url)
    }

    private func classify(_ response: HTTPResult, originalURL: URL) -> BookmarkCheckResult {
        let code = response.statusCode

        if (200...399).contains(code) {
            if response.finalURL.absoluteString != originalURL.absoluteString {
                return .redirected(statusCode: code, destination: response.finalURL)
            }
            return .working(statusCode: code)
        }

        switch code {
        case 401, 403:
            return .restricted(statusCode: code)
        case 404, 410:
            return .broken(statusCode: code)
        case 429:
            return .rateLimited
        case 500...599:
            return .serverError(statusCode: code)
        default:
            return .broken(statusCode: code)
        }
    }
}

private struct HTTPResult {
    let statusCode: Int
    let finalURL: URL
}

enum BookmarkCheckResult: Codable, Equatable, Sendable {
    case working(statusCode: Int)
    case redirected(statusCode: Int, destination: URL)
    case restricted(statusCode: Int)
    case broken(statusCode: Int)
    case rateLimited
    case serverError(statusCode: Int)
    case timedOut
    case networkError(String)

    var label: String {
        switch self {
        case .working:
            "Working"
        case .redirected:
            "Redirected"
        case .restricted:
            "Sign-in or access required"
        case .broken(let statusCode):
            "Broken (\(statusCode))"
        case .rateLimited:
            "Temporarily limited"
        case .serverError(let statusCode):
            "Server problem (\(statusCode))"
        case .timedOut:
            "Timed out"
        case .networkError:
            "Could not connect"
        }
    }

    var redirectDestination: URL? {
        if case .redirected(_, let destination) = self {
            return destination
        }
        return nil
    }
}

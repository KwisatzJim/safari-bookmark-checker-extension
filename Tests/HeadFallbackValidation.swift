import Foundation
@main struct HeadFallbackValidation {
    static func main() async {
        let base = CommandLine.arguments[1]
        let validator = BookmarkValidator()
        for (path, expected) in [("/head404", BookmarkCheckResult.working(statusCode: 200)), ("/missing", .broken(statusCode: 404)), ("/gone", .broken(statusCode: 410))] {
            let result = await validator.check(Bookmark(title: path, url: URL(string: base + path)!))
            precondition(result == expected, "Unexpected result: \(result)")
            print("PASS \(path): \(result.label)")
        }
    }
}

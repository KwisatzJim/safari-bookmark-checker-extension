import Foundation

enum BookmarkStatusFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case duplicates = "Duplicates"
    case broken = "Broken"
    case redirected = "Redirected"
    case uncertain = "Uncertain"
    case working = "Working"
    case notChecked = "Not Checked"

    var id: Self { self }

    func includes(_ result: BookmarkCheckResult?, isWebLink: Bool, isDuplicate: Bool) -> Bool {
        if self == .all { return true }
        guard isWebLink else { return false }
        if self == .duplicates { return isDuplicate }
        switch (self, result) {
        case (.broken, .broken), (.redirected, .redirected), (.working, .working):
            return true
        case (.uncertain, .restricted), (.uncertain, .rateLimited),
             (.uncertain, .serverError), (.uncertain, .timedOut), (.uncertain, .networkError):
            return true
        case (.notChecked, nil):
            return true
        default:
            return false
        }
    }
}

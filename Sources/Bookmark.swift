import Foundation

struct Bookmark: Identifiable, Equatable, Sendable {
    let id: UUID
    let sourceIndex: Int?
    let folderPath: [String]
    var title: String
    var url: URL

    init(
        id: UUID = UUID(),
        sourceIndex: Int? = nil,
        folderPath: [String] = [],
        title: String,
        url: URL
    ) {
        self.id = id
        self.sourceIndex = sourceIndex
        self.folderPath = folderPath
        self.title = title
        self.url = url
    }
}

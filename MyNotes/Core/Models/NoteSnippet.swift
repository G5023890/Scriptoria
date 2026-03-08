import Foundation

enum NoteSnippetSourceType: String, Codable, Hashable, Sendable {
    case automatic
    case manual
}

struct NoteSnippet: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let noteID: NoteID
    var language: String
    var title: String?
    var snippetDescription: String?
    var code: String
    var startOffset: Int?
    var endOffset: Int?
    var sourceType: NoteSnippetSourceType
    let createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    var deletedAt: Date?
    var version: Int
}

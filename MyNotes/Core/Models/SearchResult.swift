import Foundation

struct SearchResult: Identifiable, Hashable, Sendable {
    enum Kind: String, Hashable, Sendable {
        case note
        case snippet
        case attachment
        case label
    }

    let id: String
    let noteID: NoteID
    let title: String
    let excerpt: String
    let matchedField: String
    let kind: Kind
    let score: Int
}

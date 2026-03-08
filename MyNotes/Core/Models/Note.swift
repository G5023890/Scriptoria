import Foundation

struct Note: Identifiable, Codable, Hashable, Sendable {
    let id: NoteID
    var title: String
    var bodyMarkdown: String
    var bodyPlainText: String
    var previewText: String
    var primaryType: NotePrimaryType
    var snippetLanguageHint: String?
    let createdAt: Date
    var updatedAt: Date
    var sortDate: Date
    var isPinned: Bool
    var isFavorite: Bool
    var isArchived: Bool
    var isDeleted: Bool
    var deletedAt: Date?
    var version: Int
}

struct NoteDraft: Equatable, Sendable {
    let noteID: NoteID
    var title: String
    var bodyMarkdown: String
    var labels: [Label]
    var attachments: [Attachment]
    var snippets: [NoteSnippet]
    var hasChanges: Bool

    init(
        note: Note,
        labels: [Label] = [],
        attachments: [Attachment] = [],
        snippets: [NoteSnippet] = []
    ) {
        noteID = note.id
        title = note.title
        bodyMarkdown = note.bodyMarkdown
        self.labels = labels
        self.attachments = attachments
        self.snippets = snippets
        hasChanges = false
    }
}

struct NoteSnapshot: Identifiable, Sendable {
    let note: Note
    let labels: [Label]
    let attachments: [Attachment]
    let snippets: [NoteSnippet]

    var id: NoteID { note.id }
    var hasAttachments: Bool { !attachments.isEmpty }
    var hasSnippets: Bool { !snippets.isEmpty }
}

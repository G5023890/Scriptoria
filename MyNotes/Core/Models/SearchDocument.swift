import Foundation

struct SearchDocument: Identifiable, Hashable, Sendable {
    let id: NoteID
    let title: String
    let bodyPlainText: String
    let labelsText: String
    let snippetsText: String
    let attachmentNames: String
    let primaryType: NotePrimaryType
    let snippetLanguageHint: String?
    let updatedAt: Date
    let isPinned: Bool
    let isFavorite: Bool
    let hasTasks: Bool
    let hasAttachments: Bool
    let languagesText: String
}

import Foundation

struct NoteRowModel: Identifiable {
    let note: Note
    let labels: [Label]
    let attachmentCount: Int
    let snippetCount: Int

    init(note: Note, labels: [Label], attachmentCount: Int, snippetCount: Int) {
        self.note = note
        self.labels = labels
        self.attachmentCount = attachmentCount
        self.snippetCount = snippetCount
    }

    init(snapshot: NoteSnapshot) {
        self.init(
            note: snapshot.note,
            labels: snapshot.labels,
            attachmentCount: snapshot.attachments.count,
            snippetCount: snapshot.snippets.count
        )
    }

    var id: NoteID { note.id }
    var title: String { note.displayTitle }
    var previewText: String { note.previewText }
    var visibleLabels: [Label] { Array(labels.prefix(2)) }
    var extraLabelCount: Int { max(0, labels.count - visibleLabels.count) }
    var isPinned: Bool { note.isPinned }
    var isFavorite: Bool { note.isFavorite }
    var hasAttachments: Bool { attachmentCount > 0 }
    var hasCodeSnippets: Bool { snippetCount > 0 }
    var updatedDisplayText: String { note.updatedAt.relativeDisplayString() }
}

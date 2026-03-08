import Foundation

struct IndexNoteForSearchUseCase {
    let getNoteSnapshotUseCase: GetNoteSnapshotUseCase
    let searchIndexRepository: any SearchIndexRepository

    func execute(noteID: NoteID) async throws {
        guard let snapshot = try await getNoteSnapshotUseCase.execute(noteID: noteID) else {
            try await searchIndexRepository.remove(noteID: noteID)
            return
        }

        let snippetsText = snapshot.snippets
            .map { snippet in
                [snippet.language, snippet.title, snippet.snippetDescription, snippet.code]
                    .compactMap { $0 }
                    .joined(separator: " ")
            }
            .joined(separator: "\n")

        let attachmentNames = snapshot.attachments
            .map { attachment in
                let fileExtension = URL(fileURLWithPath: attachment.originalFileName).pathExtension
                return [
                    attachment.originalFileName,
                    attachment.fileName,
                    attachment.mimeType,
                    attachment.category.rawValue,
                    fileExtension.isEmpty ? nil : fileExtension
                ]
                .compactMap { $0 }
                .joined(separator: " ")
            }
            .joined(separator: " ")

        let document = SearchDocument(
            id: snapshot.note.id,
            title: snapshot.note.title,
            bodyPlainText: snapshot.note.bodyPlainText,
            labelsText: snapshot.labels.map(\.name).joined(separator: " "),
            snippetsText: snippetsText,
            attachmentNames: attachmentNames,
            primaryType: snapshot.note.primaryType,
            snippetLanguageHint: snapshot.note.snippetLanguageHint,
            updatedAt: snapshot.note.updatedAt,
            isPinned: snapshot.note.isPinned,
            isFavorite: snapshot.note.isFavorite,
            hasAttachments: snapshot.hasAttachments,
            languagesText: snapshot.snippets.map(\.language).joined(separator: " ")
        )
        try await searchIndexRepository.upsert(document)
    }
}

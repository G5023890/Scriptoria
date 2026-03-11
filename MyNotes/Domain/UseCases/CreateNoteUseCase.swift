import Foundation

struct CreateNoteUseCase {
    let notesRepository: any NotesRepository
    let markdownService: any MarkdownService
    let dateService: any DateService
    let indexNoteForSearchUseCase: IndexNoteForSearchUseCase

    func execute(
        title: String,
        bodyMarkdown: String,
        isPinned: Bool = false,
        isFavorite: Bool = false
    ) async throws -> Note {
        let now = dateService.now()
        let note = Note(
            id: NoteID(),
            title: title,
            bodyMarkdown: bodyMarkdown,
            bodyPlainText: markdownService.plainText(from: bodyMarkdown),
            previewText: markdownService.previewText(from: bodyMarkdown, limit: 160),
            primaryType: markdownService.detectPrimaryType(in: bodyMarkdown),
            snippetLanguageHint: markdownService.detectSnippetLanguageHint(in: bodyMarkdown),
            createdAt: now,
            updatedAt: now,
            sortDate: now,
            isPinned: isPinned,
            isFavorite: isFavorite,
            isArchived: false,
            isDeleted: false,
            deletedAt: nil,
            version: 1
        )
        try await notesRepository.create(note: note)
        try await indexNoteForSearchUseCase.execute(noteID: note.id)
        return note
    }
}

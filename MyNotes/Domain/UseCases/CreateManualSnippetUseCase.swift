import Foundation

struct CreateManualSnippetUseCase {
    let attachmentsRepository: any AttachmentsRepository
    let indexNoteForSearchUseCase: IndexNoteForSearchUseCase
    let dateService: any DateService

    func execute(
        noteID: NoteID,
        title: String,
        description: String,
        language: String,
        code: String
    ) async throws -> NoteSnippet? {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else { return nil }

        let now = dateService.now()
        var snippets = try await attachmentsRepository.snippets(for: noteID)
        let snippet = NoteSnippet(
            id: UUID().uuidString.lowercased(),
            noteID: noteID,
            language: SnippetSyntaxLanguage.normalizedID(for: language),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Snippet",
            snippetDescription: description.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            code: trimmedCode,
            startOffset: nil,
            endOffset: nil,
            sourceType: .manual,
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
            deletedAt: nil,
            version: 1
        )
        snippets.append(snippet)
        _ = try await attachmentsRepository.replaceSnippets(snippets, for: noteID)
        try await indexNoteForSearchUseCase.execute(noteID: noteID)
        return snippet
    }
}

import Foundation

struct UpdateManualSnippetUseCase {
    let attachmentsRepository: any AttachmentsRepository
    let indexNoteForSearchUseCase: IndexNoteForSearchUseCase
    let dateService: any DateService

    func execute(
        snippetID: String,
        noteID: NoteID,
        title: String,
        description: String,
        language: String,
        code: String
    ) async throws -> NoteSnippet? {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else { return nil }

        var snippets = try await attachmentsRepository.snippets(for: noteID, includeCode: true)
        guard let index = snippets.firstIndex(where: { $0.id == snippetID }) else {
            return nil
        }

        var snippet = snippets[index]
        snippet.title = title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Snippet"
        snippet.snippetDescription = description.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        snippet.language = SnippetSyntaxLanguage.normalizedID(for: language)
        snippet.code = trimmedCode
        snippet.sourceType = .manual
        snippet.updatedAt = dateService.now()
        snippet.version += 1

        snippets[index] = snippet
        _ = try await attachmentsRepository.replaceSnippets(snippets, for: noteID)
        try await indexNoteForSearchUseCase.execute(noteID: noteID)
        return snippet
    }
}

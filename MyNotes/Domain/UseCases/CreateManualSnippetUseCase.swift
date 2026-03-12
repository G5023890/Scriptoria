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

        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Snippet"
        let normalizedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let normalizedLanguage = SnippetSyntaxLanguage.normalizedID(for: language)

        let existingSnippets = try await attachmentsRepository.snippets(for: noteID, includeCode: true)
        if let existingSnippet = existingSnippets.first(where: {
            $0.sourceType == .manual &&
            ($0.title ?? "Snippet") == normalizedTitle &&
            $0.snippetDescription == normalizedDescription &&
            $0.language == normalizedLanguage &&
            $0.code == trimmedCode
        }) {
            return existingSnippet
        }

        let now = dateService.now()
        var snippets = existingSnippets
        let snippet = NoteSnippet(
            id: UUID().uuidString.lowercased(),
            noteID: noteID,
            language: normalizedLanguage,
            title: normalizedTitle,
            snippetDescription: normalizedDescription,
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

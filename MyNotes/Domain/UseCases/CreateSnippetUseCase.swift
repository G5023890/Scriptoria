import Foundation

struct CreateSnippetUseCase {
    let attachmentsRepository: any AttachmentsRepository
    let snippetDetectionPolicy: SnippetDetectionPolicy
    let dateService: any DateService
    let indexNoteForSearchUseCase: IndexNoteForSearchUseCase

    func execute(for note: Note) async throws -> [NoteSnippet] {
        let now = dateService.now()
        let detectedSnippets = snippetDetectionPolicy.extractSnippets(from: note, createdAt: now)
        let existingSnippets = try await attachmentsRepository.snippets(for: note.id, includeCode: true)
        let existingManualSnippets = existingSnippets.filter { $0.sourceType == .manual }
        let existingAutomaticSnippets = existingSnippets.filter { $0.sourceType == .automatic }
        let existingByID = Dictionary(uniqueKeysWithValues: existingAutomaticSnippets.map { ($0.id, $0) })

        let mergedAutomaticSnippets = detectedSnippets.map { detected -> NoteSnippet in
            guard let existing = existingByID[detected.id] else {
                return detected
            }

            let hasChanges =
                existing.language != detected.language ||
                existing.title != detected.title ||
                existing.snippetDescription != detected.snippetDescription ||
                existing.code != detected.code ||
                existing.startOffset != detected.startOffset ||
                existing.endOffset != detected.endOffset ||
                existing.sourceType != detected.sourceType ||
                existing.isDeleted

            guard hasChanges else {
                return existing
            }

            return NoteSnippet(
                id: existing.id,
                noteID: existing.noteID,
                language: detected.language,
                title: detected.title,
                snippetDescription: detected.snippetDescription,
                code: detected.code,
                startOffset: detected.startOffset,
                endOffset: detected.endOffset,
                sourceType: detected.sourceType,
                createdAt: existing.createdAt,
                updatedAt: now,
                isDeleted: false,
                deletedAt: nil,
                version: existing.version + 1
            )
        }

        let mergedSnippets = existingManualSnippets + mergedAutomaticSnippets
        _ = try await attachmentsRepository.replaceSnippets(mergedSnippets, for: note.id)
        try await indexNoteForSearchUseCase.execute(noteID: note.id)
        return mergedSnippets
    }
}

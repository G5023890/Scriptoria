import Foundation

struct ArchiveSnippetUseCase {
    let attachmentsRepository: any AttachmentsRepository
    let indexNoteForSearchUseCase: IndexNoteForSearchUseCase

    func execute(snippetID: String) async throws -> NoteSnippet? {
        let snippet = try await attachmentsRepository.setSnippetArchived(
            snippetID: snippetID,
            isArchived: true
        )

        if let snippet {
            try await indexNoteForSearchUseCase.execute(noteID: snippet.noteID)
        }

        return snippet
    }
}

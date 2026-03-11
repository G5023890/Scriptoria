import Foundation

struct RemoveSnippetUseCase {
    let attachmentsRepository: any AttachmentsRepository
    let indexNoteForSearchUseCase: IndexNoteForSearchUseCase

    func execute(snippetID: String, noteID: NoteID) async throws {
        let snippets = try await attachmentsRepository.snippets(for: noteID, includeCode: true)
        let remainingSnippets = snippets.filter { $0.id != snippetID }
        _ = try await attachmentsRepository.replaceSnippets(remainingSnippets, for: noteID)
        try await indexNoteForSearchUseCase.execute(noteID: noteID)
    }
}

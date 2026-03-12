import Foundation

struct RemoveSnippetUseCase {
    let attachmentsRepository: any AttachmentsRepository
    let indexNoteForSearchUseCase: IndexNoteForSearchUseCase

    func execute(snippetID: String, noteID: NoteID) async throws {
        let snippets = try await attachmentsRepository.snippets(for: noteID, includeCode: true)
        let targetSnippet = snippets.first(where: { $0.id == snippetID })

        let remainingSnippets = snippets.filter { snippet in
            guard snippet.id != snippetID else { return false }

            guard
                let targetSnippet,
                targetSnippet.sourceType == .manual,
                snippet.sourceType == .manual
            else {
                return true
            }

            let isExactDuplicate =
                snippet.title == targetSnippet.title &&
                snippet.snippetDescription == targetSnippet.snippetDescription &&
                snippet.language == targetSnippet.language &&
                snippet.code == targetSnippet.code

            return !isExactDuplicate
        }

        _ = try await attachmentsRepository.replaceSnippets(remainingSnippets, for: noteID)
        try await indexNoteForSearchUseCase.execute(noteID: noteID)
    }
}

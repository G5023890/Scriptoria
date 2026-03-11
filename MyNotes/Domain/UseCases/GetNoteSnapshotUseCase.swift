import Foundation

struct GetNoteSnapshotUseCase {
    let notesRepository: any NotesRepository
    let labelsRepository: any LabelsRepository
    let attachmentsRepository: any AttachmentsRepository
    let toDoRepository: any ToDoRepository

    func execute(
        noteID: NoteID,
        includeSnippetCode: Bool = true,
        includeDeletedToDos: Bool = false
    ) async throws -> NoteSnapshot? {
        guard let note = try await notesRepository.note(id: noteID) else {
            return nil
        }

        let labels = try await labelsRepository.labels(for: noteID)
        let todos = try await toDoRepository.listForNote(noteID: noteID, includeDeleted: includeDeletedToDos)
        let attachments = try await attachmentsRepository.attachments(for: noteID)
        let snippets = try await attachmentsRepository.snippets(for: noteID, includeCode: includeSnippetCode)
        return NoteSnapshot(note: note, labels: labels, todos: todos, attachments: attachments, snippets: snippets)
    }
}

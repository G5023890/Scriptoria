import Foundation

struct ListToDosForNoteUseCase {
    let toDoRepository: any ToDoRepository

    func execute(noteID: NoteID, includeDeleted: Bool = false) async throws -> [ToDo] {
        try await toDoRepository
            .listForNote(noteID: noteID, includeDeleted: includeDeleted)
            .sorted(by: ToDoSorting.note)
    }
}

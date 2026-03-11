import Foundation

struct ReorderToDosUseCase {
    let toDoRepository: any ToDoRepository
    let dateService: any DateService

    func execute(noteID: NoteID, orderedToDoIDs: [ToDoID]) async throws {
        try await toDoRepository.reorder(
            noteID: noteID,
            orderedToDoIDs: orderedToDoIDs,
            updatedAt: dateService.now()
        )
    }
}

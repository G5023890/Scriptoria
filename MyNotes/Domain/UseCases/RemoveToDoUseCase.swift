import Foundation

struct RemoveToDoUseCase {
    let toDoRepository: any ToDoRepository
    let refreshToDoNotificationsUseCase: RefreshToDoNotificationsUseCase

    func execute(toDoID: ToDoID) async throws {
        try await toDoRepository.remove(toDoID: toDoID)
        await refreshToDoNotificationsUseCase.execute(promptIfNeeded: false)
    }
}

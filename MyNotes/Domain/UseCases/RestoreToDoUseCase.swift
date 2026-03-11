import Foundation

struct RestoreToDoUseCase {
    let toDoRepository: any ToDoRepository
    let dateService: any DateService
    let refreshToDoNotificationsUseCase: RefreshToDoNotificationsUseCase

    func execute(toDoID: ToDoID) async throws {
        try await toDoRepository.restore(toDoID: toDoID, restoredAt: dateService.now())
        await refreshToDoNotificationsUseCase.execute(promptIfNeeded: false)
    }
}

import Foundation

struct RemoveToDoUseCase {
    let toDoRepository: any ToDoRepository
    let dateService: any DateService
    let refreshToDoNotificationsUseCase: RefreshToDoNotificationsUseCase

    func execute(toDoID: ToDoID) async throws {
        try await toDoRepository.softDelete(toDoID: toDoID, deletedAt: dateService.now())
        await refreshToDoNotificationsUseCase.execute(promptIfNeeded: false)
    }
}

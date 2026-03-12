import Foundation

struct CompleteToDoUseCase {
    let toDoRepository: any ToDoRepository
    let dateService: any DateService
    let refreshToDoNotificationsUseCase: RefreshToDoNotificationsUseCase

    func execute(toDoID: ToDoID, isCompleted: Bool) async throws {
        let now = dateService.now()
        try await toDoRepository.setCompleted(
            isCompleted,
            for: toDoID,
            isArchived: isCompleted,
            completedAt: isCompleted ? now : nil,
            updatedAt: now
        )
        await refreshToDoNotificationsUseCase.execute(promptIfNeeded: false)
    }
}

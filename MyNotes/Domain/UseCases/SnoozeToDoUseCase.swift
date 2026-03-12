import Foundation

struct SnoozeToDoUseCase {
    let toDoRepository: any ToDoRepository
    let dateService: any DateService
    let calendar: Calendar
    let refreshToDoNotificationsUseCase: RefreshToDoNotificationsUseCase

    func execute(toDoID: ToDoID, preset: ToDoNotificationSnoozePreset) async throws {
        guard var todo = try await toDoRepository.todo(id: toDoID) else { return }
        guard !todo.isDeleted, !todo.isCompleted, !todo.isArchived, todo.hasTimeComponent, todo.dueDate != nil else { return }

        let now = dateService.now()
        todo.snoozedUntil = preset.snoozedUntil(from: now, calendar: calendar)
        todo.updatedAt = now
        todo.version += 1

        try await toDoRepository.update(todo: todo)
        await refreshToDoNotificationsUseCase.execute(promptIfNeeded: false)
    }
}

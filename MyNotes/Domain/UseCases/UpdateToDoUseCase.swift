import Foundation

struct UpdateToDoUseCase {
    let toDoRepository: any ToDoRepository
    let dateService: any DateService
    let refreshToDoNotificationsUseCase: RefreshToDoNotificationsUseCase

    func execute(draft: ToDoDraft) async throws -> ToDo? {
        guard let toDoID = draft.toDoID, var todo = try await toDoRepository.todo(id: toDoID) else {
            return nil
        }

        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }

        todo.title = title
        todo.details = draft.details.trimmingCharacters(in: .whitespacesAndNewlines)
        todo.dueDate = draft.dueDate
        todo.hasTimeComponent = draft.dueDate == nil ? false : draft.hasTimeComponent
        todo.snoozedUntil = nil
        todo.updatedAt = dateService.now()
        todo.version += 1

        try await toDoRepository.update(todo: todo)
        await refreshToDoNotificationsUseCase.execute(promptIfNeeded: shouldPromptForNotification(todo))
        return todo
    }

    private func shouldPromptForNotification(_ todo: ToDo) -> Bool {
        guard let dueDate = todo.dueDate else { return false }
        return todo.hasTimeComponent && !todo.isCompleted && !todo.isArchived && !todo.isDeleted && dueDate > dateService.now()
    }
}

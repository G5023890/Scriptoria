import Foundation

struct CreateToDoUseCase {
    let toDoRepository: any ToDoRepository
    let dateService: any DateService
    let refreshToDoNotificationsUseCase: RefreshToDoNotificationsUseCase

    func execute(draft: ToDoDraft) async throws -> ToDo? {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }

        let now = dateService.now()
        let todo = ToDo(
            id: ToDoID(),
            noteID: draft.noteID,
            title: title,
            details: draft.details.trimmingCharacters(in: .whitespacesAndNewlines),
            isCompleted: false,
            dueDate: draft.dueDate,
            hasTimeComponent: draft.dueDate == nil ? false : draft.hasTimeComponent,
            snoozedUntil: nil,
            createdAt: now,
            updatedAt: now,
            completedAt: nil,
            sortOrder: try await toDoRepository.nextSortOrder(noteID: draft.noteID),
            priority: nil,
            version: 1,
            isDeleted: false,
            deletedAt: nil
        )

        try await toDoRepository.create(todo: todo)
        await refreshToDoNotificationsUseCase.execute(promptIfNeeded: shouldPromptForNotification(todo))
        return todo
    }

    private func shouldPromptForNotification(_ todo: ToDo) -> Bool {
        guard let dueDate = todo.dueDate else { return false }
        return todo.hasTimeComponent && !todo.isCompleted && !todo.isDeleted && dueDate > dateService.now()
    }
}

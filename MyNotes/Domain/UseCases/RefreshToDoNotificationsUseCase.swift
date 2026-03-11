import Foundation

struct RefreshToDoNotificationsUseCase {
    let toDoRepository: any ToDoRepository
    let notificationScheduler: any ToDoNotificationScheduling

    func execute(promptIfNeeded: Bool) async {
        do {
            let items = try await toDoRepository.listAllActiveForTasksView()
                .filter { item in
                    let todo = item.todo
                    return !todo.isCompleted && todo.hasTimeComponent && todo.dueDate != nil
                }
                .compactMap { item -> ScheduledToDoNotification? in
                    guard let dueDate = item.todo.dueDate else { return nil }
                    return ScheduledToDoNotification(
                        toDoID: item.todo.id,
                        noteID: item.todo.noteID,
                        title: item.todo.title,
                        noteTitle: item.noteTitle.nilIfEmpty ?? "Untitled",
                        details: item.todo.details,
                        dueDate: dueDate,
                        snoozedUntil: item.todo.snoozedUntil
                    )
                }

            await notificationScheduler.sync(with: items, promptIfNeeded: promptIfNeeded)
        } catch {
            print("ToDo notification refresh failed: \(error)")
        }
    }
}

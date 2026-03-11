import Foundation

struct ListAllToDosUseCase {
    let toDoRepository: any ToDoRepository
    let calendar: Calendar
    let dateService: any DateService

    func execute() async throws -> [ToDoTaskListItem] {
        let now = dateService.now()
        return try await toDoRepository.listAllActiveForTasksView()
            .map { item in
                ToDoTaskListItem(
                    todo: item.todo,
                    noteTitle: item.noteTitle,
                    group: ToDoSorting.group(for: item.todo, calendar: calendar, now: now)
                )
            }
            .sorted(by: taskSort)
    }

    private func taskSort(lhs: ToDoTaskListItem, rhs: ToDoTaskListItem) -> Bool {
        if groupRank(lhs.group) != groupRank(rhs.group) {
            return groupRank(lhs.group) < groupRank(rhs.group)
        }

        switch (lhs.todo.dueDate, rhs.todo.dueDate) {
        case let (.some(left), .some(right)):
            if left != right {
                return left < right
            }
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            break
        }

        if lhs.todo.sortOrder != rhs.todo.sortOrder {
            return lhs.todo.sortOrder < rhs.todo.sortOrder
        }

        if lhs.todo.createdAt != rhs.todo.createdAt {
            return lhs.todo.createdAt < rhs.todo.createdAt
        }

        return lhs.todo.id.rawValue < rhs.todo.id.rawValue
    }

    private func groupRank(_ group: ToDoTaskListItem.Group) -> Int {
        switch group {
        case .overdue: 0
        case .today: 1
        case .upcoming: 2
        case .noDate: 3
        case .completed: 4
        }
    }
}

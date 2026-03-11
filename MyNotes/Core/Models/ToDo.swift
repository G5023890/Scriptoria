import Foundation

struct ToDo: Identifiable, Codable, Hashable, Sendable {
    let id: ToDoID
    let noteID: NoteID
    var title: String
    var details: String
    var isCompleted: Bool
    var dueDate: Date?
    var hasTimeComponent: Bool
    var snoozedUntil: Date?
    let createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var sortOrder: Int
    var priority: String?
    var version: Int
    var isDeleted: Bool
    var deletedAt: Date?
}

struct ToDoDraft: Equatable, Sendable, Identifiable {
    var toDoID: ToDoID?
    let noteID: NoteID
    var title: String
    var details: String
    var dueDate: Date?
    var hasTimeComponent: Bool

    var id: String {
        toDoID?.rawValue ?? "draft-\(noteID.rawValue)"
    }

    init(noteID: NoteID) {
        toDoID = nil
        self.noteID = noteID
        title = ""
        details = ""
        dueDate = nil
        hasTimeComponent = false
    }

    init(todo: ToDo) {
        toDoID = todo.id
        noteID = todo.noteID
        title = todo.title
        details = todo.details
        dueDate = todo.dueDate
        hasTimeComponent = todo.hasTimeComponent
    }
}

struct ToDoTaskListItem: Identifiable, Hashable, Sendable {
    enum Group: String, CaseIterable, Hashable, Sendable {
        case overdue
        case today
        case upcoming
        case noDate
        case completed

        var title: String {
            switch self {
            case .overdue: "Overdue"
            case .today: "Today"
            case .upcoming: "Upcoming"
            case .noDate: "No Date"
            case .completed: "Completed"
            }
        }
    }

    let todo: ToDo
    let noteTitle: String
    let group: Group

    var id: ToDoID { todo.id }
}

enum ToDoSorting {
    static func note(lhs: ToDo, rhs: ToDo) -> Bool {
        if lhs.isDeleted != rhs.isDeleted {
            return !lhs.isDeleted && rhs.isDeleted
        }

        if lhs.isDeleted && rhs.isDeleted {
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.sortOrder < rhs.sortOrder
        }

        if lhs.isCompleted != rhs.isCompleted {
            return !lhs.isCompleted && rhs.isCompleted
        }

        switch (lhs.dueDate, rhs.dueDate) {
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

        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }

        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }

        return lhs.id.rawValue < rhs.id.rawValue
    }

    static func group(
        for todo: ToDo,
        calendar: Calendar,
        now: Date
    ) -> ToDoTaskListItem.Group {
        if todo.isCompleted {
            return .completed
        }

        guard let dueDate = todo.dueDate else {
            return .noDate
        }

        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            return .noDate
        }

        if dueDate < startOfToday {
            return .overdue
        }

        if dueDate < startOfTomorrow {
            return .today
        }

        return .upcoming
    }
}

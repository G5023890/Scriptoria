import Foundation

struct NoteToDoItem: Identifiable, Sendable {
    let todo: ToDo
    let title: String
    let details: String
    let dueText: String?
    let canMoveUp: Bool
    let canMoveDown: Bool

    var id: ToDoID { todo.id }
    var isCompleted: Bool { todo.isCompleted }
    var isArchived: Bool { todo.isArchived }
    var isDeleted: Bool { todo.isDeleted }
}

struct GlobalToDoRowModel: Identifiable, Sendable {
    let item: ToDoTaskListItem
    let title: String
    let noteTitle: String
    let dueText: String?

    var id: ToDoID { item.id }
    var todo: ToDo { item.todo }
    var group: ToDoTaskListItem.Group { item.group }
}

enum ToDoPresentationBuilder {
    static func makeNoteItems(from todos: [ToDo]) -> (active: [NoteToDoItem], deleted: [NoteToDoItem]) {
        let activeTodos = todos.filter { !$0.isDeleted }
        let deletedTodos = todos.filter(\.isDeleted)

        let active = activeTodos.enumerated().map { index, todo in
            NoteToDoItem(
                todo: todo,
                title: todo.title,
                details: todo.details,
                dueText: dueText(for: todo),
                canMoveUp: index > 0,
                canMoveDown: index < activeTodos.count - 1
            )
        }

        let deleted = deletedTodos.enumerated().map { index, todo in
            NoteToDoItem(
                todo: todo,
                title: todo.title,
                details: todo.details,
                dueText: dueText(for: todo),
                canMoveUp: index > 0,
                canMoveDown: index < deletedTodos.count - 1
            )
        }

        return (active, deleted)
    }

    static func makeGlobalRow(_ item: ToDoTaskListItem) -> GlobalToDoRowModel {
        GlobalToDoRowModel(
            item: item,
            title: item.todo.title,
            noteTitle: item.noteTitle.nilIfEmpty ?? "Untitled",
            dueText: dueText(for: item.todo)
        )
    }

    static func dueText(for todo: ToDo) -> String? {
        guard let dueDate = todo.dueDate else { return nil }
        return dueDate.fixedDateString()
    }
}

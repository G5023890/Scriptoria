import Foundation

protocol ToDoRepository {
    func todo(id: ToDoID) async throws -> ToDo?
    func create(todo: ToDo) async throws
    func update(todo: ToDo) async throws
    func softDelete(toDoID: ToDoID, deletedAt: Date) async throws
    func remove(toDoID: ToDoID) async throws
    func restore(toDoID: ToDoID, restoredAt: Date) async throws
    func setCompleted(_ isCompleted: Bool, for toDoID: ToDoID, completedAt: Date?, updatedAt: Date) async throws
    func reorder(noteID: NoteID, orderedToDoIDs: [ToDoID], updatedAt: Date) async throws
    func listForNote(noteID: NoteID, includeDeleted: Bool) async throws -> [ToDo]
    func listAllActiveForTasksView() async throws -> [ToDoTaskListItem]
    func countForSidebar() async throws -> Int
    func nextSortOrder(noteID: NoteID) async throws -> Int
}

struct LocalToDoRepository: ToDoRepository {
    let dataSource: ToDoLocalDataSource

    func todo(id: ToDoID) async throws -> ToDo? {
        try dataSource.todo(id: id)
    }

    func create(todo: ToDo) async throws {
        try dataSource.create(todo)
    }

    func update(todo: ToDo) async throws {
        try dataSource.update(todo)
    }

    func softDelete(toDoID: ToDoID, deletedAt: Date) async throws {
        try dataSource.softDelete(toDoID: toDoID, deletedAt: deletedAt)
    }

    func remove(toDoID: ToDoID) async throws {
        try dataSource.remove(toDoID: toDoID)
    }

    func restore(toDoID: ToDoID, restoredAt: Date) async throws {
        try dataSource.restore(toDoID: toDoID, restoredAt: restoredAt)
    }

    func setCompleted(_ isCompleted: Bool, for toDoID: ToDoID, completedAt: Date?, updatedAt: Date) async throws {
        try dataSource.setCompleted(isCompleted, for: toDoID, completedAt: completedAt, updatedAt: updatedAt)
    }

    func reorder(noteID: NoteID, orderedToDoIDs: [ToDoID], updatedAt: Date) async throws {
        try dataSource.reorder(noteID: noteID, orderedToDoIDs: orderedToDoIDs, updatedAt: updatedAt)
    }

    func listForNote(noteID: NoteID, includeDeleted: Bool) async throws -> [ToDo] {
        try dataSource.listForNote(noteID: noteID, includeDeleted: includeDeleted)
    }

    func listAllActiveForTasksView() async throws -> [ToDoTaskListItem] {
        try dataSource.listAllActiveForTasksView()
    }

    func countForSidebar() async throws -> Int {
        try dataSource.countForSidebar()
    }

    func nextSortOrder(noteID: NoteID) async throws -> Int {
        try dataSource.nextSortOrder(noteID: noteID)
    }
}

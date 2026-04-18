import Foundation

protocol ToDoRepository {
    func todo(id: ToDoID) async throws -> ToDo?
    func create(todo: ToDo) async throws
    func update(todo: ToDo) async throws
    func softDelete(toDoID: ToDoID, deletedAt: Date) async throws
    func remove(toDoID: ToDoID) async throws
    func restore(toDoID: ToDoID, restoredAt: Date) async throws
    func setCompleted(_ isCompleted: Bool, for toDoID: ToDoID, isArchived: Bool, completedAt: Date?, updatedAt: Date) async throws
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

    func setCompleted(_ isCompleted: Bool, for toDoID: ToDoID, isArchived: Bool, completedAt: Date?, updatedAt: Date) async throws {
        try dataSource.setCompleted(
            isCompleted,
            for: toDoID,
            isArchived: isArchived,
            completedAt: completedAt,
            updatedAt: updatedAt
        )
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

struct SyncAwareToDoRepository: ToDoRepository {
    let base: any ToDoRepository
    let syncQueue: any SyncQueue

    func todo(id: ToDoID) async throws -> ToDo? {
        try await base.todo(id: id)
    }

    func create(todo: ToDo) async throws {
        try await base.create(todo: todo)
        try await enqueue(entityID: todo.id.rawValue, operation: .create, payloadVersion: todo.version)
    }

    func update(todo: ToDo) async throws {
        try await base.update(todo: todo)
        guard let updated = try await base.todo(id: todo.id) else { return }
        try await enqueue(entityID: updated.id.rawValue, operation: .update, payloadVersion: updated.version)
    }

    func softDelete(toDoID: ToDoID, deletedAt: Date) async throws {
        try await base.softDelete(toDoID: toDoID, deletedAt: deletedAt)
        guard let updated = try await base.todo(id: toDoID) else { return }
        try await enqueue(entityID: updated.id.rawValue, operation: .delete, payloadVersion: updated.version)
    }

    func remove(toDoID: ToDoID) async throws {
        let existing = try await base.todo(id: toDoID)
        try await base.remove(toDoID: toDoID)
        try await enqueue(entityID: toDoID.rawValue, operation: .delete, payloadVersion: (existing?.version ?? 0) + 1)
    }

    func restore(toDoID: ToDoID, restoredAt: Date) async throws {
        try await base.restore(toDoID: toDoID, restoredAt: restoredAt)
        guard let updated = try await base.todo(id: toDoID) else { return }
        try await enqueue(entityID: updated.id.rawValue, operation: .update, payloadVersion: updated.version)
    }

    func setCompleted(
        _ isCompleted: Bool,
        for toDoID: ToDoID,
        isArchived: Bool,
        completedAt: Date?,
        updatedAt: Date
    ) async throws {
        try await base.setCompleted(
            isCompleted,
            for: toDoID,
            isArchived: isArchived,
            completedAt: completedAt,
            updatedAt: updatedAt
        )
        guard let updated = try await base.todo(id: toDoID) else { return }
        try await enqueue(entityID: updated.id.rawValue, operation: .update, payloadVersion: updated.version)
    }

    func reorder(noteID: NoteID, orderedToDoIDs: [ToDoID], updatedAt: Date) async throws {
        try await base.reorder(noteID: noteID, orderedToDoIDs: orderedToDoIDs, updatedAt: updatedAt)
        for toDoID in orderedToDoIDs {
            guard let updated = try await base.todo(id: toDoID) else { continue }
            try await enqueue(entityID: updated.id.rawValue, operation: .update, payloadVersion: updated.version)
        }
    }

    func listForNote(noteID: NoteID, includeDeleted: Bool) async throws -> [ToDo] {
        try await base.listForNote(noteID: noteID, includeDeleted: includeDeleted)
    }

    func listAllActiveForTasksView() async throws -> [ToDoTaskListItem] {
        try await base.listAllActiveForTasksView()
    }

    func countForSidebar() async throws -> Int {
        try await base.countForSidebar()
    }

    func nextSortOrder(noteID: NoteID) async throws -> Int {
        try await base.nextSortOrder(noteID: noteID)
    }

    private func enqueue(entityID: String, operation: SyncQueueItem.Operation, payloadVersion: Int) async throws {
        _ = try await syncQueue.enqueuePendingLocalChange(
            SyncEnqueueRequest(
                entityType: .toDo,
                entityID: entityID,
                operation: operation,
                payloadVersion: payloadVersion
            )
        )
    }
}

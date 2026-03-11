import Foundation

struct ToDoLocalDataSource {
    private let databaseManager: DatabaseManager

    init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
    }

    func todo(id: ToDoID) throws -> ToDo? {
        try databaseManager.read { db in
            try todo(id: id, using: db)
        }
    }

    func create(_ todo: ToDo) throws {
        try databaseManager.write { db in
            try upsert(todo, using: db)
        }
    }

    func update(_ todo: ToDo) throws {
        try databaseManager.write { db in
            try upsert(todo, using: db)
        }
    }

    func softDelete(toDoID: ToDoID, deletedAt: Date) throws {
        let timestamp = DatabaseDateCodec.encode(deletedAt)
        try databaseManager.write { db in
            try db.execute(
                statement: """
                UPDATE todos
                SET is_deleted = 1,
                    deleted_at = ?,
                    snoozed_until = NULL,
                    updated_at = ?,
                    version = version + 1
                WHERE id = ?;
                """,
                bindings: [
                    .text(timestamp),
                    .text(timestamp),
                    .text(toDoID.rawValue)
                ]
            )
        }
    }

    func remove(toDoID: ToDoID) throws {
        try databaseManager.write { db in
            try db.execute(
                statement: "DELETE FROM todos WHERE id = ?;",
                bindings: [.text(toDoID.rawValue)]
            )
        }
    }

    func restore(toDoID: ToDoID, restoredAt: Date) throws {
        let timestamp = DatabaseDateCodec.encode(restoredAt)
        try databaseManager.write { db in
            try db.execute(
                statement: """
                UPDATE todos
                SET is_deleted = 0,
                    deleted_at = NULL,
                    snoozed_until = NULL,
                    updated_at = ?,
                    version = version + 1
                WHERE id = ?;
                """,
                bindings: [
                    .text(timestamp),
                    .text(toDoID.rawValue)
                ]
            )
        }
    }

    func setCompleted(
        _ isCompleted: Bool,
        for toDoID: ToDoID,
        completedAt: Date?,
        updatedAt: Date
    ) throws {
        try databaseManager.write { db in
            try db.execute(
                statement: """
                UPDATE todos
                SET is_completed = ?,
                    completed_at = ?,
                    snoozed_until = NULL,
                    updated_at = ?,
                    version = version + 1
                WHERE id = ?;
                """,
                bindings: [
                    .integer(isCompleted ? 1 : 0),
                    completedAt.map { .text(DatabaseDateCodec.encode($0)) } ?? .null,
                    .text(DatabaseDateCodec.encode(updatedAt)),
                    .text(toDoID.rawValue)
                ]
            )
        }
    }

    func reorder(noteID: NoteID, orderedToDoIDs: [ToDoID], updatedAt: Date) throws {
        let timestamp = DatabaseDateCodec.encode(updatedAt)
        try databaseManager.transaction { db in
            for (index, toDoID) in orderedToDoIDs.enumerated() {
                try db.execute(
                    statement: """
                    UPDATE todos
                    SET sort_order = ?,
                        updated_at = ?,
                        version = version + 1
                    WHERE id = ?
                      AND note_id = ?;
                    """,
                    bindings: [
                        .integer(Int64(index)),
                        .text(timestamp),
                        .text(toDoID.rawValue),
                        .text(noteID.rawValue)
                    ]
                )
            }
        }
    }

    func listForNote(noteID: NoteID, includeDeleted: Bool) throws -> [ToDo] {
        try databaseManager.read { db in
            var sql = """
            SELECT
                id,
                note_id,
                title,
                details,
                is_completed,
                due_date,
                has_time_component,
                snoozed_until,
                priority,
                sort_order,
                created_at,
                updated_at,
                completed_at,
                is_deleted,
                deleted_at,
                version
            FROM todos
            WHERE note_id = ?
            """
            if !includeDeleted {
                sql += "\n  AND is_deleted = 0"
            }
            sql += "\nORDER BY sort_order ASC, created_at ASC;"

            return try db.query(
                statement: sql,
                bindings: [.text(noteID.rawValue)],
                map: Self.mapToDo
            )
        }
    }

    func listAllActiveForTasksView() throws -> [ToDoTaskListItem] {
        try databaseManager.read { db in
            try db.query(
                statement: """
                SELECT
                    t.id,
                    t.note_id,
                    t.title,
                    t.details,
                    t.is_completed,
                    t.due_date,
                    t.has_time_component,
                    t.snoozed_until,
                    t.priority,
                    t.sort_order,
                    t.created_at,
                    t.updated_at,
                    t.completed_at,
                    t.is_deleted,
                    t.deleted_at,
                    t.version,
                    n.title AS note_title
                FROM todos t
                INNER JOIN notes n ON n.id = t.note_id
                WHERE t.is_deleted = 0
                  AND n.is_deleted = 0
                  AND n.is_archived = 0;
                """,
                map: Self.mapTaskListItem
            )
        }
    }

    func countForSidebar() throws -> Int {
        try databaseManager.read { db in
            try db.scalarInt(
                statement: """
                SELECT COUNT(*) AS value
                FROM todos t
                INNER JOIN notes n ON n.id = t.note_id
                WHERE t.is_deleted = 0
                  AND t.is_completed = 0
                  AND n.is_deleted = 0
                  AND n.is_archived = 0;
                """
            ) ?? 0
        }
    }

    func nextSortOrder(noteID: NoteID) throws -> Int {
        try databaseManager.read { db in
            try db.scalarInt(
                statement: """
                SELECT COALESCE(MAX(sort_order) + 1, 0) AS value
                FROM todos
                WHERE note_id = ?;
                """,
                bindings: [.text(noteID.rawValue)]
            ) ?? 0
        }
    }

    fileprivate func todo(id: ToDoID, using db: SQLiteConnection) throws -> ToDo? {
        try db.queryOne(
            statement: """
            SELECT
                id,
                note_id,
                title,
                details,
                is_completed,
                due_date,
                has_time_component,
                snoozed_until,
                priority,
                sort_order,
                created_at,
                updated_at,
                completed_at,
                is_deleted,
                deleted_at,
                version
            FROM todos
            WHERE id = ?;
            """,
            bindings: [.text(id.rawValue)],
            map: Self.mapToDo
        )
    }

    fileprivate func upsert(_ todo: ToDo, using db: SQLiteConnection) throws {
        try db.execute(
            statement: """
            INSERT INTO todos (
                id,
                note_id,
                title,
                details,
                is_completed,
                due_date,
                has_time_component,
                snoozed_until,
                priority,
                sort_order,
                created_at,
                updated_at,
                completed_at,
                is_deleted,
                deleted_at,
                version
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                note_id = excluded.note_id,
                title = excluded.title,
                details = excluded.details,
                is_completed = excluded.is_completed,
                due_date = excluded.due_date,
                has_time_component = excluded.has_time_component,
                snoozed_until = excluded.snoozed_until,
                priority = excluded.priority,
                sort_order = excluded.sort_order,
                created_at = excluded.created_at,
                updated_at = excluded.updated_at,
                completed_at = excluded.completed_at,
                is_deleted = excluded.is_deleted,
                deleted_at = excluded.deleted_at,
                version = excluded.version;
            """,
            bindings: [
                .text(todo.id.rawValue),
                .text(todo.noteID.rawValue),
                .text(todo.title),
                todo.details.nilIfEmpty.map(SQLiteValue.text) ?? .null,
                .integer(todo.isCompleted ? 1 : 0),
                todo.dueDate.map { .text(DatabaseDateCodec.encode($0)) } ?? .null,
                .integer(todo.hasTimeComponent ? 1 : 0),
                todo.snoozedUntil.map { .text(DatabaseDateCodec.encode($0)) } ?? .null,
                todo.priority.map(SQLiteValue.text) ?? .null,
                .integer(Int64(todo.sortOrder)),
                .text(DatabaseDateCodec.encode(todo.createdAt)),
                .text(DatabaseDateCodec.encode(todo.updatedAt)),
                todo.completedAt.map { .text(DatabaseDateCodec.encode($0)) } ?? .null,
                .integer(todo.isDeleted ? 1 : 0),
                todo.deletedAt.map { .text(DatabaseDateCodec.encode($0)) } ?? .null,
                .integer(Int64(todo.version))
            ]
        )
    }

    private static func mapToDo(_ row: SQLiteRow) throws -> ToDo {
        let deletedAtValue = try row.string("deleted_at")
        let completedAtValue = try row.string("completed_at")
        let dueDateValue = try row.string("due_date")
        let snoozedUntilValue = try row.string("snoozed_until")

        return ToDo(
            id: ToDoID(rawValue: try row.requiredString("id")),
            noteID: NoteID(rawValue: try row.requiredString("note_id")),
            title: try row.requiredString("title"),
            details: try row.string("details") ?? "",
            isCompleted: try row.bool("is_completed"),
            dueDate: try dueDateValue.map(DatabaseDateCodec.decode),
            hasTimeComponent: try row.bool("has_time_component"),
            snoozedUntil: try snoozedUntilValue.map(DatabaseDateCodec.decode),
            createdAt: try DatabaseDateCodec.decode(try row.requiredString("created_at")),
            updatedAt: try DatabaseDateCodec.decode(try row.requiredString("updated_at")),
            completedAt: try completedAtValue.map(DatabaseDateCodec.decode),
            sortOrder: try row.requiredInt("sort_order"),
            priority: try row.string("priority"),
            version: try row.requiredInt("version"),
            isDeleted: try row.bool("is_deleted"),
            deletedAt: try deletedAtValue.map(DatabaseDateCodec.decode)
        )
    }

    private static func mapTaskListItem(_ row: SQLiteRow) throws -> ToDoTaskListItem {
        let todo = try mapToDo(row)
        let group = ToDoTaskListItem.Group.noDate

        return ToDoTaskListItem(
            todo: todo,
            noteTitle: try row.requiredString("note_title"),
            group: group
        )
    }
}

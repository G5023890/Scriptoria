import Foundation

struct NotesLocalDataSource {
    private let databaseManager: DatabaseManager

    init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
    }

    func count() throws -> Int {
        try databaseManager.read { db in
            try db.scalarInt(statement: "SELECT COUNT(*) AS value FROM notes;") ?? 0
        }
    }

    func note(id: NoteID) throws -> Note? {
        try databaseManager.read { db in
            try note(id: id, using: db)
        }
    }

    func list(query: NoteQuery) throws -> [Note] {
        try databaseManager.read { db in
            let statement = makeListStatement(query: query)
            return try db.query(
                statement: statement.sql,
                bindings: statement.bindings,
                map: Self.mapNote
            )
        }
    }

    func recentNotes(limit: Int) throws -> [Note] {
        var query = NoteQuery(collection: .recent)
        query.includeDeleted = false
        return try databaseManager.read { db in
            let statement = makeListStatement(query: query, limit: limit)
            return try db.query(
                statement: statement.sql,
                bindings: statement.bindings,
                map: Self.mapNote
            )
        }
    }

    func create(_ note: Note) throws {
        try databaseManager.write { db in
            try upsert(note, using: db)
        }
    }

    func update(_ note: Note) throws {
        try databaseManager.write { db in
            try upsert(note, using: db)
        }
    }

    func softDelete(noteID: NoteID, deletedAt: Date) throws {
        let deletedAtString = DatabaseDateCodec.encode(deletedAt)
        try databaseManager.write { db in
            try db.execute(
                statement: """
                UPDATE notes
                SET is_deleted = 1,
                    deleted_at = ?,
                    updated_at = ?,
                    sort_date = ?,
                    version = version + 1
                WHERE id = ?;
                """,
                bindings: [
                    .text(deletedAtString),
                    .text(deletedAtString),
                    .text(deletedAtString),
                    .text(noteID.rawValue)
                ]
            )
        }
    }

    func restore(noteID: NoteID, restoredAt: Date) throws {
        let restoredAtString = DatabaseDateCodec.encode(restoredAt)
        try databaseManager.write { db in
            try db.execute(
                statement: """
                UPDATE notes
                SET is_deleted = 0,
                    deleted_at = NULL,
                    updated_at = ?,
                    sort_date = ?,
                    version = version + 1
                WHERE id = ?;
                """,
                bindings: [
                    .text(restoredAtString),
                    .text(restoredAtString),
                    .text(noteID.rawValue)
                ]
            )
        }
    }

    func setPinned(_ isPinned: Bool, for noteID: NoteID, updatedAt: Date) throws {
        let timestamp = DatabaseDateCodec.encode(updatedAt)
        try databaseManager.write { db in
            try db.execute(
                statement: """
                UPDATE notes
                SET is_pinned = ?,
                    updated_at = ?,
                    sort_date = ?,
                    version = version + 1
                WHERE id = ?;
                """,
                bindings: [
                    .integer(isPinned ? 1 : 0),
                    .text(timestamp),
                    .text(timestamp),
                    .text(noteID.rawValue)
                ]
            )
        }
    }

    func setFavorite(_ isFavorite: Bool, for noteID: NoteID, updatedAt: Date) throws {
        let timestamp = DatabaseDateCodec.encode(updatedAt)
        try databaseManager.write { db in
            try db.execute(
                statement: """
                UPDATE notes
                SET is_favorite = ?,
                    updated_at = ?,
                    sort_date = ?,
                    version = version + 1
                WHERE id = ?;
                """,
                bindings: [
                    .integer(isFavorite ? 1 : 0),
                    .text(timestamp),
                    .text(timestamp),
                    .text(noteID.rawValue)
                ]
            )
        }
    }

    fileprivate func note(id: NoteID, using db: SQLiteConnection) throws -> Note? {
        try db.queryOne(
            statement: """
            SELECT
                id,
                title,
                body_markdown,
                body_plain_text,
                preview_text,
                primary_type,
                snippet_language_hint,
                is_pinned,
                is_favorite,
                is_archived,
                is_deleted,
                deleted_at,
                created_at,
                updated_at,
                sort_date,
                version
            FROM notes
            WHERE id = ?;
            """,
            bindings: [.text(id.rawValue)],
            map: Self.mapNote
        )
    }

    fileprivate func upsert(_ note: Note, using db: SQLiteConnection) throws {
        try db.execute(
            statement: """
            INSERT INTO notes (
                id,
                title,
                body_markdown,
                body_plain_text,
                preview_text,
                primary_type,
                snippet_language_hint,
                is_pinned,
                is_favorite,
                is_archived,
                is_deleted,
                deleted_at,
                created_at,
                updated_at,
                sort_date,
                version
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                title = excluded.title,
                body_markdown = excluded.body_markdown,
                body_plain_text = excluded.body_plain_text,
                preview_text = excluded.preview_text,
                primary_type = excluded.primary_type,
                snippet_language_hint = excluded.snippet_language_hint,
                is_pinned = excluded.is_pinned,
                is_favorite = excluded.is_favorite,
                is_archived = excluded.is_archived,
                is_deleted = excluded.is_deleted,
                deleted_at = excluded.deleted_at,
                created_at = excluded.created_at,
                updated_at = excluded.updated_at,
                sort_date = excluded.sort_date,
                version = excluded.version;
            """,
            bindings: [
                .text(note.id.rawValue),
                .text(note.title),
                .text(note.bodyMarkdown),
                .text(note.bodyPlainText),
                .text(note.previewText),
                note.primaryType.rawValue.nilIfEmpty.map(SQLiteValue.text) ?? .null,
                note.snippetLanguageHint.map(SQLiteValue.text) ?? .null,
                .integer(note.isPinned ? 1 : 0),
                .integer(note.isFavorite ? 1 : 0),
                .integer(note.isArchived ? 1 : 0),
                .integer(note.isDeleted ? 1 : 0),
                note.deletedAt.map { .text(DatabaseDateCodec.encode($0)) } ?? .null,
                .text(DatabaseDateCodec.encode(note.createdAt)),
                .text(DatabaseDateCodec.encode(note.updatedAt)),
                .text(DatabaseDateCodec.encode(note.sortDate)),
                .integer(Int64(note.version))
            ]
        )
    }

    private func makeListStatement(query: NoteQuery, limit: Int? = nil) -> (sql: String, bindings: [SQLiteValue]) {
        var predicates: [String] = []
        var bindings: [SQLiteValue] = []

        switch query.collection {
        case .trash:
            predicates.append("n.is_deleted = 1")
        default:
            if !query.includeDeleted {
                predicates.append("n.is_deleted = 0")
            }
        }

        switch query.collection {
        case .allNotes:
            predicates.append("n.is_archived = 0")
        case .favorites:
            predicates.append("n.is_archived = 0")
            predicates.append("n.is_favorite = 1")
        case .pinned:
            predicates.append("n.is_archived = 0")
            predicates.append("n.is_pinned = 1")
        case .recent:
            predicates.append("n.is_archived = 0")
            predicates.append("n.updated_at >= ?")
            bindings.append(.text(DatabaseDateCodec.encode(Date().addingTimeInterval(-7 * 24 * 60 * 60))))
        case .attachments:
            predicates.append("n.is_archived = 0")
            predicates.append("""
            EXISTS (
                SELECT 1
                FROM attachments a
                WHERE a.note_id = n.id
                  AND a.is_deleted = 0
            )
            """)
        case .snippets:
            predicates.append("n.is_archived = 0")
            predicates.append("""
            EXISTS (
                SELECT 1
                FROM snippets s
                WHERE s.note_id = n.id
                  AND s.is_deleted = 0
            )
            """)
        case .trash:
            break
        }

        if let labelID = query.labelID {
            predicates.append("""
            EXISTS (
                SELECT 1
                FROM note_labels nl
                JOIN labels l ON l.id = nl.label_id
                WHERE nl.note_id = n.id
                  AND nl.label_id = ?
                  AND l.is_deleted = 0
            )
            """)
            bindings.append(.text(labelID.rawValue))
        }

        let whereClause = predicates.isEmpty ? "" : "WHERE " + predicates.joined(separator: " AND ")
        let limitClause = limit.map { " LIMIT \($0)" } ?? ""

        return (
            sql: """
            SELECT
                n.id,
                n.title,
                n.body_markdown,
                n.body_plain_text,
                n.preview_text,
                n.primary_type,
                n.snippet_language_hint,
                n.is_pinned,
                n.is_favorite,
                n.is_archived,
                n.is_deleted,
                n.deleted_at,
                n.created_at,
                n.updated_at,
                n.sort_date,
                n.version
            FROM notes n
            \(whereClause)
            ORDER BY \(sortClause(for: query.sortOrder))
            \(limitClause);
            """,
            bindings: bindings
        )
    }

    private func sortClause(for sortOrder: NoteSortOrder) -> String {
        switch sortOrder {
        case .pinnedThenUpdated:
            "n.is_pinned DESC, n.sort_date DESC, n.updated_at DESC"
        case .updatedDescending:
            "n.updated_at DESC"
        case .createdDescending:
            "n.created_at DESC"
        case .titleAscending:
            "n.title COLLATE NOCASE ASC"
        }
    }

    private static func mapNote(row: SQLiteRow) throws -> Note {
        let deletedAtValue = try row.string("deleted_at")

        return Note(
            id: NoteID(rawValue: try row.requiredString("id")),
            title: try row.requiredString("title"),
            bodyMarkdown: try row.requiredString("body_markdown"),
            bodyPlainText: try row.requiredString("body_plain_text"),
            previewText: try row.requiredString("preview_text"),
            primaryType: NotePrimaryType(rawValue: try row.string("primary_type") ?? "") ?? .note,
            snippetLanguageHint: try row.string("snippet_language_hint"),
            createdAt: try DatabaseDateCodec.decode(try row.requiredString("created_at")),
            updatedAt: try DatabaseDateCodec.decode(try row.requiredString("updated_at")),
            sortDate: try DatabaseDateCodec.decode(try row.requiredString("sort_date")),
            isPinned: try row.bool("is_pinned"),
            isFavorite: try row.bool("is_favorite"),
            isArchived: try row.bool("is_archived"),
            isDeleted: try row.bool("is_deleted"),
            deletedAt: try deletedAtValue.map { try DatabaseDateCodec.decode($0) },
            version: try row.requiredInt("version")
        )
    }
}

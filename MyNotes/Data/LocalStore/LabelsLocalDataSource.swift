import Foundation

struct LabelsLocalDataSource {
    private let databaseManager: DatabaseManager

    init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
    }

    struct NoteLabelAssignment: Hashable, Sendable {
        let noteID: NoteID
        let labelID: LabelID
    }

    func allLabels() throws -> [Label] {
        try databaseManager.read { db in
            try db.query(
                statement: """
                SELECT
                    id,
                    name,
                    color,
                    icon_name,
                    is_system,
                    created_at,
                    updated_at,
                    is_deleted,
                    deleted_at,
                    version
                FROM labels
                WHERE is_deleted = 0
                ORDER BY name COLLATE NOCASE ASC;
                """,
                map: Self.mapLabel
            )
        }
    }

    func allLabelsIncludingDeleted() throws -> [Label] {
        try databaseManager.read { db in
            try db.query(
                statement: """
                SELECT
                    id,
                    name,
                    color,
                    icon_name,
                    is_system,
                    created_at,
                    updated_at,
                    is_deleted,
                    deleted_at,
                    version
                FROM labels
                ORDER BY name COLLATE NOCASE ASC;
                """,
                map: Self.mapLabel
            )
        }
    }

    func label(id: LabelID) throws -> Label? {
        try databaseManager.read { db in
            try label(id: id, using: db)
        }
    }

    func labels(for noteID: NoteID) throws -> [Label] {
        try databaseManager.read { db in
            try db.query(
                statement: """
                SELECT
                    l.id,
                    l.name,
                    l.color,
                    l.icon_name,
                    l.is_system,
                    l.created_at,
                    l.updated_at,
                    l.is_deleted,
                    l.deleted_at,
                    l.version
                FROM labels l
                JOIN note_labels nl ON nl.label_id = l.id
                WHERE nl.note_id = ?
                  AND l.is_deleted = 0
                ORDER BY l.name COLLATE NOCASE ASC;
                """,
                bindings: [.text(noteID.rawValue)],
                map: Self.mapLabel
            )
        }
    }

    func noteIDs(for labelID: LabelID) throws -> [NoteID] {
        try databaseManager.read { db in
            try db.query(
                statement: """
                SELECT n.id
                FROM note_labels nl
                JOIN notes n ON n.id = nl.note_id
                JOIN labels l ON l.id = nl.label_id
                WHERE nl.label_id = ?
                  AND l.is_deleted = 0
                  AND n.is_deleted = 0
                  AND n.is_archived = 0
                ORDER BY n.sort_date DESC, n.updated_at DESC;
                """,
                bindings: [.text(labelID.rawValue)]
            ) { row in
                NoteID(rawValue: try row.requiredString("id"))
            }
        }
    }

    func create(_ label: Label) throws {
        try databaseManager.write { db in
            try upsert(label, using: db)
        }
    }

    func update(_ label: Label) throws {
        try databaseManager.write { db in
            try db.execute(
                statement: """
                UPDATE labels
                SET name = ?,
                    color = ?,
                    icon_name = ?,
                    updated_at = ?,
                    version = ?
                WHERE id = ?
                  AND is_deleted = 0;
                """,
                bindings: [
                    .text(label.name),
                    label.color.map(SQLiteValue.text) ?? .null,
                    label.iconName.map(SQLiteValue.text) ?? .null,
                    .text(DatabaseDateCodec.encode(label.updatedAt)),
                    .integer(Int64(label.version)),
                    .text(label.id.rawValue)
                ]
            )
        }
    }

    func delete(labelID: LabelID, deletedAt: Date) throws {
        let timestamp = DatabaseDateCodec.encode(deletedAt)

        try databaseManager.transaction { db in
            guard let label = try label(id: labelID, using: db), !label.isSystem else {
                return
            }

            try db.execute(
                statement: """
                UPDATE labels
                SET is_deleted = 1,
                    deleted_at = ?,
                    updated_at = ?,
                    version = version + 1
                WHERE id = ?;
                """,
                bindings: [
                    .text(timestamp),
                    .text(timestamp),
                    .text(labelID.rawValue)
                ]
            )
            try db.execute(
                statement: "DELETE FROM note_labels WHERE label_id = ?;",
                bindings: [.text(labelID.rawValue)]
            )
        }
    }

    func assign(labelIDs: [LabelID], to noteID: NoteID) throws {
        let uniqueLabelIDs = Array(Set(labelIDs))

        try databaseManager.transaction { db in
            try db.execute(
                statement: "DELETE FROM note_labels WHERE note_id = ?;",
                bindings: [.text(noteID.rawValue)]
            )

            for labelID in uniqueLabelIDs {
                try db.execute(
                    statement: """
                    INSERT OR IGNORE INTO note_labels (note_id, label_id)
                    SELECT ?, ?
                    WHERE EXISTS (
                        SELECT 1
                        FROM labels
                        WHERE id = ?
                          AND is_deleted = 0
                    );
                    """,
                    bindings: [
                        .text(noteID.rawValue),
                        .text(labelID.rawValue),
                        .text(labelID.rawValue)
                    ]
                )
            }
        }
    }

    func remove(labelID: LabelID, from noteID: NoteID) throws {
        try databaseManager.write { db in
            try db.execute(
                statement: """
                DELETE FROM note_labels
                WHERE note_id = ?
                  AND label_id = ?;
                """,
                bindings: [
                    .text(noteID.rawValue),
                    .text(labelID.rawValue)
                ]
            )
        }
    }

    func allNoteLabelAssignments() throws -> [NoteLabelAssignment] {
        try databaseManager.read { db in
            try db.query(
                statement: """
                SELECT note_id, label_id
                FROM note_labels
                ORDER BY note_id ASC, label_id ASC;
                """
            ) { row in
                NoteLabelAssignment(
                    noteID: NoteID(rawValue: try row.requiredString("note_id")),
                    labelID: LabelID(rawValue: try row.requiredString("label_id"))
                )
            }
        }
    }

    func add(labelID: LabelID, to noteID: NoteID) throws {
        try databaseManager.write { db in
            try db.execute(
                statement: """
                INSERT OR IGNORE INTO note_labels (note_id, label_id)
                SELECT ?, ?
                WHERE EXISTS (
                    SELECT 1
                    FROM notes
                    WHERE id = ?
                      AND is_deleted = 0
                )
                  AND EXISTS (
                    SELECT 1
                    FROM labels
                    WHERE id = ?
                      AND is_deleted = 0
                );
                """,
                bindings: [
                    .text(noteID.rawValue),
                    .text(labelID.rawValue),
                    .text(noteID.rawValue),
                    .text(labelID.rawValue)
                ]
            )
        }
    }

    fileprivate func label(id: LabelID, using db: SQLiteConnection) throws -> Label? {
        try db.queryOne(
            statement: """
            SELECT
                id,
                name,
                color,
                icon_name,
                is_system,
                created_at,
                updated_at,
                is_deleted,
                deleted_at,
                version
            FROM labels
            WHERE id = ?;
            """,
            bindings: [.text(id.rawValue)],
            map: Self.mapLabel
        )
    }

    fileprivate func upsert(_ label: Label, using db: SQLiteConnection) throws {
        try db.execute(
            statement: """
            INSERT INTO labels (
                id,
                name,
                color,
                icon_name,
                is_system,
                created_at,
                updated_at,
                is_deleted,
                deleted_at,
                version
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                color = excluded.color,
                icon_name = excluded.icon_name,
                is_system = excluded.is_system,
                created_at = excluded.created_at,
                updated_at = excluded.updated_at,
                is_deleted = excluded.is_deleted,
                deleted_at = excluded.deleted_at,
                version = excluded.version;
            """,
            bindings: [
                .text(label.id.rawValue),
                .text(label.name),
                label.color.map(SQLiteValue.text) ?? .null,
                label.iconName.map(SQLiteValue.text) ?? .null,
                .integer(label.isSystem ? 1 : 0),
                .text(DatabaseDateCodec.encode(label.createdAt)),
                .text(DatabaseDateCodec.encode(label.updatedAt)),
                .integer(label.isDeleted ? 1 : 0),
                label.deletedAt.map { .text(DatabaseDateCodec.encode($0)) } ?? .null,
                .integer(Int64(label.version))
            ]
        )
    }

    private static func mapLabel(row: SQLiteRow) throws -> Label {
        let deletedAtValue = try row.string("deleted_at")

        return Label(
            id: LabelID(rawValue: try row.requiredString("id")),
            name: try row.requiredString("name"),
            color: try row.string("color"),
            iconName: try row.string("icon_name"),
            isSystem: try row.bool("is_system"),
            createdAt: try DatabaseDateCodec.decode(try row.requiredString("created_at")),
            updatedAt: try DatabaseDateCodec.decode(try row.requiredString("updated_at")),
            isDeleted: try row.bool("is_deleted"),
            deletedAt: try deletedAtValue.map { try DatabaseDateCodec.decode($0) },
            version: try row.requiredInt("version")
        )
    }
}

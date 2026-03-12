import Foundation

struct AttachmentsLocalDataSource {
    private let databaseManager: DatabaseManager

    init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
    }

    func attachments(for noteID: NoteID) throws -> [Attachment] {
        try databaseManager.read { db in
            try db.query(
                statement: """
                SELECT
                    id,
                    note_id,
                    file_name,
                    original_file_name,
                    mime_type,
                    category,
                    relative_path,
                    file_size,
                    checksum,
                    width,
                    height,
                    duration,
                    page_count,
                    created_at,
                    updated_at,
                    is_deleted,
                    deleted_at,
                    version
                FROM attachments
                WHERE note_id = ?
                  AND is_deleted = 0
                ORDER BY created_at DESC;
                """,
                bindings: [.text(noteID.rawValue)],
                map: Self.mapAttachment
            )
        }
    }

    func attachment(id: AttachmentID) throws -> Attachment? {
        try databaseManager.read { db in
            try attachment(id: id, using: db)
        }
    }

    func add(_ attachment: Attachment) throws {
        try databaseManager.write { db in
            try upsertAttachment(attachment, using: db)
        }
    }

    func softDelete(attachmentID: AttachmentID, deletedAt: Date) throws -> Attachment? {
        try databaseManager.transaction { db in
            guard let attachment = try attachment(id: attachmentID, using: db) else {
                return nil
            }

            let timestamp = DatabaseDateCodec.encode(deletedAt)
            try db.execute(
                statement: """
                UPDATE attachments
                SET is_deleted = 1,
                    deleted_at = ?,
                    updated_at = ?,
                    version = version + 1
                WHERE id = ?;
                """,
                bindings: [
                    .text(timestamp),
                    .text(timestamp),
                    .text(attachmentID.rawValue)
                ]
            )
            return attachment
        }
    }

    func snippets(for noteID: NoteID, includeCode: Bool = true) throws -> [NoteSnippet] {
        let codeColumn = includeCode ? "code" : "'' AS code"

        return try databaseManager.read { db in
            try db.query(
                statement: """
                SELECT
                    id,
                    note_id,
                    language,
                    title,
                    description,
                    \(codeColumn),
                    start_offset,
                    end_offset,
                    source_type,
                    created_at,
                    updated_at,
                    is_deleted,
                    deleted_at,
                    version
                FROM snippets
                WHERE note_id = ?
                  AND is_deleted = 0
                ORDER BY created_at DESC;
                """,
                bindings: [.text(noteID.rawValue)],
                map: Self.mapSnippet
            )
        }
    }

    func snippet(id: String) throws -> NoteSnippet? {
        try databaseManager.read { db in
            try snippet(id: id, using: db)
        }
    }

    func replaceSnippets(_ snippets: [NoteSnippet], for noteID: NoteID) throws -> SnippetMutationResult {
        let activeSnippetIDs = snippets.map(\.id)
        let deletedAt = Date()
        let timestamp = DatabaseDateCodec.encode(deletedAt)

        return try databaseManager.transaction { db in
            let existingSnippets = try db.query(
                statement: """
                SELECT
                    id,
                    note_id,
                    language,
                    title,
                    description,
                    code,
                    start_offset,
                    end_offset,
                    source_type,
                    created_at,
                    updated_at,
                    is_deleted,
                    deleted_at,
                    version
                FROM snippets
                WHERE note_id = ?
                  AND is_deleted = 0;
                """,
                bindings: [.text(noteID.rawValue)],
                map: Self.mapSnippet
            )
            let existingActiveIDs = Set(existingSnippets.map(\.id))
            let retainedIDs = Set(activeSnippetIDs)

            if activeSnippetIDs.isEmpty {
                try db.execute(
                    statement: """
                    UPDATE snippets
                    SET is_deleted = 1,
                        deleted_at = ?,
                        updated_at = ?,
                        version = version + 1
                    WHERE note_id = ?
                      AND is_deleted = 0;
                    """,
                    bindings: [
                        .text(timestamp),
                        .text(timestamp),
                        .text(noteID.rawValue)
                    ]
                )
            } else {
                let placeholders = Array(repeating: "?", count: activeSnippetIDs.count).joined(separator: ", ")
                var bindings: [SQLiteValue] = [
                    .text(timestamp),
                    .text(timestamp),
                    .text(noteID.rawValue)
                ]
                bindings.append(contentsOf: activeSnippetIDs.map(SQLiteValue.text))

                try db.execute(
                    statement: """
                    UPDATE snippets
                    SET is_deleted = 1,
                        deleted_at = ?,
                        updated_at = ?,
                        version = version + 1
                    WHERE note_id = ?
                      AND is_deleted = 0
                      AND id NOT IN (\(placeholders));
                    """,
                    bindings: bindings
                )
            }

            for snippet in snippets {
                try upsertSnippet(snippet, using: db)
            }

            let deletedSnippets = existingSnippets
                .filter { !retainedIDs.contains($0.id) }
                .map { snippet in
                    NoteSnippet(
                        id: snippet.id,
                        noteID: snippet.noteID,
                        language: snippet.language,
                        title: snippet.title,
                        snippetDescription: snippet.snippetDescription,
                        code: snippet.code,
                        startOffset: snippet.startOffset,
                        endOffset: snippet.endOffset,
                        sourceType: snippet.sourceType,
                        createdAt: snippet.createdAt,
                        updatedAt: deletedAt,
                        isDeleted: true,
                        deletedAt: deletedAt,
                        version: snippet.version + 1
                    )
                }

            let upsertedSnippets = snippets.map { snippet -> NoteSnippet in
                if existingActiveIDs.contains(snippet.id),
                   let existingSnippet = existingSnippets.first(where: { $0.id == snippet.id }) {
                    return NoteSnippet(
                        id: snippet.id,
                        noteID: snippet.noteID,
                        language: snippet.language,
                        title: snippet.title,
                        snippetDescription: snippet.snippetDescription,
                        code: snippet.code,
                        startOffset: snippet.startOffset,
                        endOffset: snippet.endOffset,
                        sourceType: snippet.sourceType,
                        createdAt: existingSnippet.createdAt,
                        updatedAt: snippet.updatedAt,
                        isDeleted: false,
                        deletedAt: nil,
                        version: max(existingSnippet.version, snippet.version)
                    )
                }
                return snippet
            }

            return SnippetMutationResult(upserted: upsertedSnippets, deleted: deletedSnippets)
        }
    }

    fileprivate func attachment(id: AttachmentID, using db: SQLiteConnection) throws -> Attachment? {
        try db.queryOne(
            statement: """
            SELECT
                id,
                note_id,
                file_name,
                original_file_name,
                mime_type,
                category,
                relative_path,
                file_size,
                checksum,
                width,
                height,
                duration,
                page_count,
                created_at,
                updated_at,
                is_deleted,
                deleted_at,
                version
            FROM attachments
            WHERE id = ?;
            """,
            bindings: [.text(id.rawValue)],
            map: Self.mapAttachment
        )
    }

    fileprivate func snippet(id: String, using db: SQLiteConnection) throws -> NoteSnippet? {
        try db.queryOne(
            statement: """
            SELECT
                id,
                note_id,
                language,
                title,
                description,
                code,
                start_offset,
                end_offset,
                source_type,
                created_at,
                updated_at,
                is_deleted,
                deleted_at,
                version
            FROM snippets
            WHERE id = ?;
            """,
            bindings: [.text(id)],
            map: Self.mapSnippet
        )
    }

    fileprivate func upsertAttachment(_ attachment: Attachment, using db: SQLiteConnection) throws {
        try db.execute(
            statement: """
            INSERT INTO attachments (
                id,
                note_id,
                file_name,
                original_file_name,
                mime_type,
                category,
                relative_path,
                file_size,
                checksum,
                width,
                height,
                duration,
                page_count,
                created_at,
                updated_at,
                is_deleted,
                deleted_at,
                version
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                note_id = excluded.note_id,
                file_name = excluded.file_name,
                original_file_name = excluded.original_file_name,
                mime_type = excluded.mime_type,
                category = excluded.category,
                relative_path = excluded.relative_path,
                file_size = excluded.file_size,
                checksum = excluded.checksum,
                width = excluded.width,
                height = excluded.height,
                duration = excluded.duration,
                page_count = excluded.page_count,
                created_at = excluded.created_at,
                updated_at = excluded.updated_at,
                is_deleted = excluded.is_deleted,
                deleted_at = excluded.deleted_at,
                version = excluded.version;
            """,
            bindings: [
                .text(attachment.id.rawValue),
                .text(attachment.noteID.rawValue),
                .text(attachment.fileName),
                .text(attachment.originalFileName),
                attachment.mimeType.map(SQLiteValue.text) ?? .null,
                .text(attachment.category.rawValue),
                .text(attachment.relativePath),
                attachment.fileSize.map(SQLiteValue.integer) ?? .null,
                attachment.checksum.map(SQLiteValue.text) ?? .null,
                attachment.width.map { .integer(Int64($0)) } ?? .null,
                attachment.height.map { .integer(Int64($0)) } ?? .null,
                attachment.duration.map(SQLiteValue.double) ?? .null,
                attachment.pageCount.map { .integer(Int64($0)) } ?? .null,
                .text(DatabaseDateCodec.encode(attachment.createdAt)),
                .text(DatabaseDateCodec.encode(attachment.updatedAt)),
                .integer(attachment.isDeleted ? 1 : 0),
                attachment.deletedAt.map { .text(DatabaseDateCodec.encode($0)) } ?? .null,
                .integer(Int64(attachment.version))
            ]
        )
    }

    fileprivate func upsertSnippet(_ snippet: NoteSnippet, using db: SQLiteConnection) throws {
        try db.execute(
            statement: """
            INSERT INTO snippets (
                id,
                note_id,
                language,
                title,
                description,
                code,
                start_offset,
                end_offset,
                source_type,
                created_at,
                updated_at,
                is_deleted,
                deleted_at,
                version
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                note_id = excluded.note_id,
                language = excluded.language,
                title = excluded.title,
                description = excluded.description,
                code = excluded.code,
                start_offset = excluded.start_offset,
                end_offset = excluded.end_offset,
                source_type = excluded.source_type,
                created_at = excluded.created_at,
                updated_at = excluded.updated_at,
                is_deleted = excluded.is_deleted,
                deleted_at = excluded.deleted_at,
                version = excluded.version;
            """,
            bindings: [
                .text(snippet.id),
                .text(snippet.noteID.rawValue),
                .text(snippet.language),
                snippet.title.map(SQLiteValue.text) ?? .null,
                snippet.snippetDescription.map(SQLiteValue.text) ?? .null,
                .text(snippet.code),
                snippet.startOffset.map { .integer(Int64($0)) } ?? .null,
                snippet.endOffset.map { .integer(Int64($0)) } ?? .null,
                .text(snippet.sourceType.rawValue),
                .text(DatabaseDateCodec.encode(snippet.createdAt)),
                .text(DatabaseDateCodec.encode(snippet.updatedAt)),
                .integer(snippet.isDeleted ? 1 : 0),
                snippet.deletedAt.map { .text(DatabaseDateCodec.encode($0)) } ?? .null,
                .integer(Int64(snippet.version))
            ]
        )
    }

    private static func mapAttachment(row: SQLiteRow) throws -> Attachment {
        let deletedAtValue = try row.string("deleted_at")

        return Attachment(
            id: AttachmentID(rawValue: try row.requiredString("id")),
            noteID: NoteID(rawValue: try row.requiredString("note_id")),
            fileName: try row.requiredString("file_name"),
            originalFileName: try row.requiredString("original_file_name"),
            mimeType: try row.string("mime_type"),
            category: AttachmentCategory(rawValue: try row.requiredString("category")) ?? .file,
            relativePath: try row.requiredString("relative_path"),
            fileSize: try row.int64("file_size"),
            checksum: try row.string("checksum"),
            width: try row.int("width"),
            height: try row.int("height"),
            duration: try row.double("duration"),
            pageCount: try row.int("page_count"),
            createdAt: try DatabaseDateCodec.decode(try row.requiredString("created_at")),
            updatedAt: try DatabaseDateCodec.decode(try row.requiredString("updated_at")),
            isDeleted: try row.bool("is_deleted"),
            deletedAt: try deletedAtValue.map { try DatabaseDateCodec.decode($0) },
            version: try row.requiredInt("version")
        )
    }

    private static func mapSnippet(row: SQLiteRow) throws -> NoteSnippet {
        let deletedAtValue = try row.string("deleted_at")

        return NoteSnippet(
            id: try row.requiredString("id"),
            noteID: NoteID(rawValue: try row.requiredString("note_id")),
            language: try row.requiredString("language"),
            title: try row.string("title"),
            snippetDescription: try row.string("description"),
            code: try row.requiredString("code"),
            startOffset: try row.int("start_offset"),
            endOffset: try row.int("end_offset"),
            sourceType: NoteSnippetSourceType(rawValue: try row.requiredString("source_type")) ?? .automatic,
            createdAt: try DatabaseDateCodec.decode(try row.requiredString("created_at")),
            updatedAt: try DatabaseDateCodec.decode(try row.requiredString("updated_at")),
            isDeleted: try row.bool("is_deleted"),
            deletedAt: try deletedAtValue.map { try DatabaseDateCodec.decode($0) },
            version: try row.requiredInt("version")
        )
    }
}

import Foundation

struct SearchDocumentMatch {
    let document: SearchDocument
    let rank: Double
}

struct SearchLocalDataSource {
    private let databaseManager: DatabaseManager

    init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
    }

    func upsert(_ document: SearchDocument) throws {
        try databaseManager.transaction { db in
            try db.execute(
                statement: "DELETE FROM notes_fts WHERE note_id = ?;",
                bindings: [.text(document.id.rawValue)]
            )
            try db.execute(
                statement: """
                INSERT INTO notes_fts (
                    note_id,
                    title,
                    body_plain_text,
                    labels_text,
                    snippets_text,
                    attachment_names,
                    primary_type,
                    snippet_language_hint,
                    updated_at,
                    is_pinned,
                    is_favorite,
                    has_attachments,
                    languages_text
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """,
                bindings: [
                    .text(document.id.rawValue),
                    .text(document.title),
                    .text(document.bodyPlainText),
                    .text(document.labelsText),
                    .text(document.snippetsText),
                    .text(document.attachmentNames),
                    .text(document.primaryType.rawValue),
                    document.snippetLanguageHint.map(SQLiteValue.text) ?? .null,
                    .text(DatabaseDateCodec.encode(document.updatedAt)),
                    .integer(document.isPinned ? 1 : 0),
                    .integer(document.isFavorite ? 1 : 0),
                    .integer(document.hasAttachments ? 1 : 0),
                    .text(document.languagesText)
                ]
            )
        }
    }

    func remove(noteID: NoteID) throws {
        try databaseManager.write { db in
            try db.execute(
                statement: "DELETE FROM notes_fts WHERE note_id = ?;",
                bindings: [.text(noteID.rawValue)]
            )
        }
    }

    func allDocuments() throws -> [SearchDocument] {
        try databaseManager.read { db in
            try db.query(
                statement: """
                \(selectSQL(rankExpression: "0"))
                \(baseWhereClause)
                ORDER BY n.sort_date DESC, f.updated_at DESC;
                """,
                map: Self.mapDocument
            )
        }
    }

    func searchDocuments(matching query: SearchQuery) throws -> [SearchDocumentMatch] {
        guard !query.terms.isEmpty else {
            return try allDocuments().map { SearchDocumentMatch(document: $0, rank: 0) }
        }

        return try databaseManager.read { db in
            try db.query(
                statement: """
                \(selectSQL(rankExpression: "bm25(notes_fts)"))
                \(baseWhereClause)
                  AND notes_fts MATCH ?
                ORDER BY rank ASC, n.sort_date DESC
                LIMIT 100;
                """,
                bindings: [.text(matchExpression(from: query.terms))]
            ) { row in
                SearchDocumentMatch(
                    document: try Self.mapDocument(row: row),
                    rank: try row.double("rank") ?? 0
                )
            }
        }
    }

    private func selectSQL(rankExpression: String) -> String {
        """
        SELECT
            f.note_id,
            f.title,
            f.body_plain_text,
            f.labels_text,
            f.snippets_text,
            f.attachment_names,
            f.primary_type,
            f.snippet_language_hint,
            f.updated_at,
            f.is_pinned,
            f.is_favorite,
            f.has_attachments,
            f.languages_text,
            \(rankExpression) AS rank
        FROM notes_fts f
        JOIN notes n ON n.id = f.note_id
        """
    }

    private var baseWhereClause: String {
        "WHERE n.is_deleted = 0"
    }

    private func matchExpression(from terms: [String]) -> String {
        terms
            .map { term in
                let escaped = term.replacingOccurrences(of: "\"", with: "\"\"")
                return "\"\(escaped)\"*"
            }
            .joined(separator: " AND ")
    }

    private static func mapDocument(row: SQLiteRow) throws -> SearchDocument {
        SearchDocument(
            id: NoteID(rawValue: try row.requiredString("note_id")),
            title: try row.requiredString("title"),
            bodyPlainText: try row.requiredString("body_plain_text"),
            labelsText: try row.requiredString("labels_text"),
            snippetsText: try row.requiredString("snippets_text"),
            attachmentNames: try row.requiredString("attachment_names"),
            primaryType: NotePrimaryType(rawValue: try row.requiredString("primary_type")) ?? .note,
            snippetLanguageHint: try row.string("snippet_language_hint"),
            updatedAt: try DatabaseDateCodec.decode(try row.requiredString("updated_at")),
            isPinned: try row.bool("is_pinned"),
            isFavorite: try row.bool("is_favorite"),
            hasAttachments: try row.bool("has_attachments"),
            languagesText: try row.requiredString("languages_text")
        )
    }
}

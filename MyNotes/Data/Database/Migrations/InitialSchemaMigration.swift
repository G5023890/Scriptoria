import Foundation

struct DatabaseMigration: Sendable {
    let version: Int
    let statements: [String]
}

enum DatabaseMigrations {
    static let all: [DatabaseMigration] = [
        InitialSchemaMigration.migration,
        SyncInfrastructureMigration.migration,
        SnippetMetadataMigration.migration,
        ToDoSchemaMigration.migration,
        ToDoNotificationStateMigration.migration,
        SearchTasksMigration.migration,
        ArtifactArchiveMigration.migration,
        ToDoArchiveMigration.migration
    ]
}

enum InitialSchemaMigration {
    static let migration = DatabaseMigration(
        version: 1,
        statements: SchemaDefinition.baseStatementsV1 + SchemaDefinition.baseIndexesV1 + FTSSchema.allStatements
    )
}

enum SyncInfrastructureMigration {
    static let migration = DatabaseMigration(
        version: 2,
        statements: [
            SchemaDefinition.syncQueueTable,
            SchemaDefinition.syncStateTable
        ] + SchemaDefinition.indexes.filter {
            $0.contains("idx_sync_queue_")
        }
    )
}

enum SnippetMetadataMigration {
    static let migration = DatabaseMigration(
        version: 3,
        statements: [
            "ALTER TABLE snippets ADD COLUMN description TEXT;",
            "ALTER TABLE snippets ADD COLUMN source_type TEXT NOT NULL DEFAULT 'automatic';"
        ]
    )
}

enum ToDoSchemaMigration {
    static let migration = DatabaseMigration(
        version: 4,
        statements: [
            SchemaDefinition.todosTableV4
        ] + SchemaDefinition.indexes.filter {
            $0.contains("idx_todos_")
        }
    )
}

enum ToDoNotificationStateMigration {
    static let migration = DatabaseMigration(
        version: 5,
        statements: [
            "ALTER TABLE todos ADD COLUMN snoozed_until TEXT;"
        ]
    )
}

enum SearchTasksMigration {
    static let migration = DatabaseMigration(
        version: 6,
        statements: [
            """
            CREATE VIRTUAL TABLE notes_fts_new USING fts5(
                note_id UNINDEXED,
                title,
                body_plain_text,
                labels_text,
                snippets_text,
                attachment_names,
                primary_type UNINDEXED,
                snippet_language_hint UNINDEXED,
                updated_at UNINDEXED,
                is_pinned UNINDEXED,
                is_favorite UNINDEXED,
                has_tasks UNINDEXED,
                has_attachments UNINDEXED,
                languages_text UNINDEXED,
                tokenize = 'unicode61 remove_diacritics 2'
            );
            """,
            """
            INSERT INTO notes_fts_new (
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
                has_tasks,
                has_attachments,
                languages_text
            )
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
                CASE
                    WHEN EXISTS (
                        SELECT 1
                        FROM todos t
                        WHERE t.note_id = f.note_id
                          AND t.is_deleted = 0
                    ) THEN 1
                    ELSE 0
                END,
                f.has_attachments,
                f.languages_text
            FROM notes_fts f;
            """,
            "DROP TABLE notes_fts;",
            "ALTER TABLE notes_fts_new RENAME TO notes_fts;"
        ]
    )
}

enum ArtifactArchiveMigration {
    static let migration = DatabaseMigration(
        version: 7,
        statements: [
            "ALTER TABLE attachments ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0;",
            "ALTER TABLE snippets ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0;"
        ]
    )
}

enum ToDoArchiveMigration {
    static let migration = DatabaseMigration(
        version: 8,
        statements: [
            "ALTER TABLE todos ADD COLUMN is_archived INTEGER NOT NULL DEFAULT 0;"
        ]
    )
}

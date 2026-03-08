import Foundation

struct DatabaseMigration: Sendable {
    let version: Int
    let statements: [String]
}

enum DatabaseMigrations {
    static let all: [DatabaseMigration] = [
        InitialSchemaMigration.migration,
        SyncInfrastructureMigration.migration,
        SnippetMetadataMigration.migration
    ]
}

enum InitialSchemaMigration {
    static let migration = DatabaseMigration(
        version: 1,
        statements: SchemaDefinition.allStatements + FTSSchema.allStatements
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

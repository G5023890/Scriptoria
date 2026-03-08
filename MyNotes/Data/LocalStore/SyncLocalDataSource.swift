import Foundation

struct SyncLocalDataSource {
    private let databaseManager: DatabaseManager

    init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
    }

    func enqueue(_ item: SyncQueueItem) throws {
        try databaseManager.write { db in
            try db.execute(
                statement: """
                INSERT INTO sync_queue (
                    id,
                    entity_type,
                    entity_id,
                    operation,
                    payload_version,
                    status,
                    retry_count,
                    next_retry_at,
                    last_attempt_at,
                    last_error,
                    created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """,
                bindings: [
                    .text(item.id),
                    .text(item.entityType.rawValue),
                    .text(item.entityID),
                    .text(item.operation.rawValue),
                    .integer(Int64(item.payloadVersion)),
                    .text(item.status.rawValue),
                    .integer(Int64(item.retryCount)),
                    item.nextRetryAt.map { .text(DatabaseDateCodec.encode($0)) } ?? .null,
                    item.lastAttemptAt.map { .text(DatabaseDateCodec.encode($0)) } ?? .null,
                    item.lastError.map(SQLiteValue.text) ?? .null,
                    .text(DatabaseDateCodec.encode(item.createdAt))
                ]
            )
        }
    }

    func queueItem(id: String) throws -> SyncQueueItem? {
        try databaseManager.read { db in
            try db.queryOne(
                statement: """
                SELECT
                    id,
                    entity_type,
                    entity_id,
                    operation,
                    payload_version,
                    status,
                    retry_count,
                    next_retry_at,
                    last_attempt_at,
                    last_error,
                    created_at
                FROM sync_queue
                WHERE id = ?;
                """,
                bindings: [.text(id)],
                map: Self.mapQueueItem
            )
        }
    }

    func pendingItems(readyBefore now: Date, limit: Int) throws -> [SyncQueueItem] {
        try databaseManager.read { db in
            try db.query(
                statement: """
                SELECT
                    id,
                    entity_type,
                    entity_id,
                    operation,
                    payload_version,
                    status,
                    retry_count,
                    next_retry_at,
                    last_attempt_at,
                    last_error,
                    created_at
                FROM sync_queue
                WHERE status IN (?, ?)
                  AND (next_retry_at IS NULL OR next_retry_at <= ?)
                ORDER BY created_at ASC
                LIMIT ?;
                """,
                bindings: [
                    .text(SyncQueueItem.Status.pending.rawValue),
                    .text(SyncQueueItem.Status.failed.rawValue),
                    .text(DatabaseDateCodec.encode(now)),
                    .integer(Int64(limit))
                ],
                map: Self.mapQueueItem
            )
        }
    }

    func pendingCount(readyBefore now: Date) throws -> Int {
        try databaseManager.read { db in
            try db.scalarInt(
                statement: """
                SELECT COUNT(*) AS value
                FROM sync_queue
                WHERE status IN (?, ?)
                  AND (next_retry_at IS NULL OR next_retry_at <= ?);
                """,
                bindings: [
                    .text(SyncQueueItem.Status.pending.rawValue),
                    .text(SyncQueueItem.Status.failed.rawValue),
                    .text(DatabaseDateCodec.encode(now))
                ]
            ) ?? 0
        }
    }

    func markProcessing(itemID: String, attemptedAt: Date) throws {
        try databaseManager.write { db in
            try db.execute(
                statement: """
                UPDATE sync_queue
                SET status = ?,
                    last_attempt_at = ?
                WHERE id = ?;
                """,
                bindings: [
                    .text(SyncQueueItem.Status.processing.rawValue),
                    .text(DatabaseDateCodec.encode(attemptedAt)),
                    .text(itemID)
                ]
            )
        }
    }

    func markFailed(
        itemID: String,
        retryCount: Int,
        nextRetryAt: Date,
        attemptedAt: Date,
        errorSummary: String?
    ) throws {
        try databaseManager.write { db in
            try db.execute(
                statement: """
                UPDATE sync_queue
                SET status = ?,
                    retry_count = ?,
                    next_retry_at = ?,
                    last_attempt_at = ?,
                    last_error = ?
                WHERE id = ?;
                """,
                bindings: [
                    .text(SyncQueueItem.Status.failed.rawValue),
                    .integer(Int64(retryCount)),
                    .text(DatabaseDateCodec.encode(nextRetryAt)),
                    .text(DatabaseDateCodec.encode(attemptedAt)),
                    errorSummary.map(SQLiteValue.text) ?? .null,
                    .text(itemID)
                ]
            )
        }
    }

    func removeProcessedItem(itemID: String) throws {
        try databaseManager.write { db in
            try db.execute(
                statement: "DELETE FROM sync_queue WHERE id = ?;",
                bindings: [.text(itemID)]
            )
        }
    }

    func value(for key: String) throws -> String? {
        try databaseManager.read { db in
            try db.queryOne(
                statement: "SELECT value FROM sync_state WHERE key = ?;",
                bindings: [.text(key)]
            ) { row in
                try row.string("value")
            } ?? nil
        }
    }

    func setValue(_ value: String?, for key: String, updatedAt: Date) throws {
        try databaseManager.write { db in
            try db.execute(
                statement: """
                INSERT INTO sync_state (key, value, updated_at)
                VALUES (?, ?, ?)
                ON CONFLICT(key) DO UPDATE SET
                    value = excluded.value,
                    updated_at = excluded.updated_at;
                """,
                bindings: [
                    .text(key),
                    value.map(SQLiteValue.text) ?? .null,
                    .text(DatabaseDateCodec.encode(updatedAt))
                ]
            )
        }
    }

    private static func mapQueueItem(row: SQLiteRow) throws -> SyncQueueItem {
        let nextRetryAtValue = try row.string("next_retry_at")
        let lastAttemptAtValue = try row.string("last_attempt_at")

        return SyncQueueItem(
            id: try row.requiredString("id"),
            entityType: SyncQueueItem.EntityType(rawValue: try row.requiredString("entity_type")) ?? .note,
            entityID: try row.requiredString("entity_id"),
            operation: SyncQueueItem.Operation(rawValue: try row.requiredString("operation")) ?? .update,
            payloadVersion: try row.requiredInt("payload_version"),
            status: SyncQueueItem.Status(rawValue: try row.requiredString("status")) ?? .pending,
            createdAt: try DatabaseDateCodec.decode(try row.requiredString("created_at")),
            retryCount: try row.requiredInt("retry_count"),
            nextRetryAt: try nextRetryAtValue.map(DatabaseDateCodec.decode),
            lastAttemptAt: try lastAttemptAtValue.map(DatabaseDateCodec.decode),
            lastError: try row.string("last_error")
        )
    }
}

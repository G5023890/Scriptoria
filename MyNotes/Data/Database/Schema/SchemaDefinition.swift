import Foundation

enum SchemaDefinition {
    static let notesTable = """
    CREATE TABLE IF NOT EXISTS notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        body_markdown TEXT NOT NULL,
        body_plain_text TEXT NOT NULL,
        preview_text TEXT NOT NULL,
        primary_type TEXT,
        snippet_language_hint TEXT,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sort_date TEXT NOT NULL,
        version INTEGER NOT NULL DEFAULT 1
    );
    """

    static let labelsTable = """
    CREATE TABLE IF NOT EXISTS labels (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        color TEXT,
        icon_name TEXT,
        is_system INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT,
        version INTEGER NOT NULL DEFAULT 1
    );
    """

    static let noteLabelsTable = """
    CREATE TABLE IF NOT EXISTS note_labels (
        note_id TEXT NOT NULL,
        label_id TEXT NOT NULL,
        PRIMARY KEY (note_id, label_id),
        FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE,
        FOREIGN KEY (label_id) REFERENCES labels(id) ON DELETE CASCADE
    );
    """

    static let attachmentsTable = """
    CREATE TABLE IF NOT EXISTS attachments (
        id TEXT PRIMARY KEY,
        note_id TEXT NOT NULL,
        file_name TEXT NOT NULL,
        original_file_name TEXT NOT NULL,
        mime_type TEXT,
        category TEXT NOT NULL,
        relative_path TEXT NOT NULL,
        file_size INTEGER,
        checksum TEXT,
        width INTEGER,
        height INTEGER,
        duration REAL,
        page_count INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT,
        version INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
    );
    """

    static let snippetsTable = """
    CREATE TABLE IF NOT EXISTS snippets (
        id TEXT PRIMARY KEY,
        note_id TEXT NOT NULL,
        language TEXT NOT NULL,
        title TEXT,
        description TEXT,
        code TEXT NOT NULL,
        start_offset INTEGER,
        end_offset INTEGER,
        source_type TEXT NOT NULL DEFAULT 'automatic',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT,
        version INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
    );
    """

    static let syncQueueTable = """
    CREATE TABLE IF NOT EXISTS sync_queue (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_version INTEGER NOT NULL DEFAULT 1,
        status TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        next_retry_at TEXT,
        last_attempt_at TEXT,
        last_error TEXT,
        created_at TEXT NOT NULL
    );
    """

    static let syncStateTable = """
    CREATE TABLE IF NOT EXISTS sync_state (
        key TEXT PRIMARY KEY,
        value TEXT,
        updated_at TEXT NOT NULL
    );
    """

    static let indexes: [String] = [
        "CREATE INDEX IF NOT EXISTS idx_notes_updated_at ON notes(updated_at DESC);",
        "CREATE INDEX IF NOT EXISTS idx_notes_sort_date ON notes(sort_date DESC);",
        "CREATE INDEX IF NOT EXISTS idx_notes_flags ON notes(is_pinned, is_favorite, is_archived, is_deleted);",
        "CREATE INDEX IF NOT EXISTS idx_note_labels_note_id ON note_labels(note_id);",
        "CREATE INDEX IF NOT EXISTS idx_note_labels_label_id ON note_labels(label_id);",
        "CREATE INDEX IF NOT EXISTS idx_attachments_note_id ON attachments(note_id);",
        "CREATE INDEX IF NOT EXISTS idx_snippets_note_id ON snippets(note_id);",
        "CREATE INDEX IF NOT EXISTS idx_snippets_language ON snippets(language);",
        "CREATE INDEX IF NOT EXISTS idx_sync_queue_status_created_at ON sync_queue(status, created_at);",
        "CREATE INDEX IF NOT EXISTS idx_sync_queue_entity ON sync_queue(entity_type, entity_id);",
        "CREATE INDEX IF NOT EXISTS idx_sync_queue_next_retry_at ON sync_queue(next_retry_at);"
    ]

    static let allStatements: [String] = [
        notesTable,
        labelsTable,
        noteLabelsTable,
        attachmentsTable,
        snippetsTable,
        syncQueueTable,
        syncStateTable
    ] + indexes
}

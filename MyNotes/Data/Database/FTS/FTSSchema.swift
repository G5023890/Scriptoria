import Foundation

enum FTSSchema {
    static let notesFTSTable = """
    CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
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
    """

    static let allStatements: [String] = [
        notesFTSTable
    ]
}

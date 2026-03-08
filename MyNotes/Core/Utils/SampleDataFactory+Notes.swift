import Foundation

extension SampleDataFactory {
    static func makeNotes(markdownService: any MarkdownService, now: Date) -> [Note] {
        [
            makeNote(
                id: "note-welcome",
                title: "MyNotes foundation checklist",
                body: """
                Build the app around repositories and use cases first.

                - local-first database
                - FTS-backed search
                - split markdown editor
                - future CloudKit sync
                """,
                markdownService: markdownService,
                createdAt: now.addingTimeInterval(-14_400),
                updatedAt: now.addingTimeInterval(-3_600),
                isPinned: true,
                isFavorite: false
            ),
            makeNote(
                id: "note-swift-snippet",
                title: "Window lifecycle snippet",
                body: """
                Keep window presentation logic out of the view body.

                ```swift
                @MainActor
                func presentQuickCapture() {
                    coordinator.isQuickCapturePresented = true
                }
                ```
                """,
                markdownService: markdownService,
                createdAt: now.addingTimeInterval(-43_200),
                updatedAt: now.addingTimeInterval(-7_200),
                isPinned: false,
                isFavorite: true
            ),
            makeNote(
                id: "note-attachments",
                title: "Attachment import pipeline",
                body: """
                Copy imported files into the app container and store only relative paths in SQLite.
                """,
                markdownService: markdownService,
                createdAt: now.addingTimeInterval(-86_400),
                updatedAt: now.addingTimeInterval(-18_000),
                isPinned: false,
                isFavorite: false
            )
        ]
    }

    private static func makeNote(
        id: String,
        title: String,
        body: String,
        markdownService: any MarkdownService,
        createdAt: Date,
        updatedAt: Date,
        isPinned: Bool,
        isFavorite: Bool
    ) -> Note {
        Note(
            id: NoteID(rawValue: id),
            title: title,
            bodyMarkdown: body,
            bodyPlainText: markdownService.plainText(from: body),
            previewText: markdownService.previewText(from: body, limit: 160),
            primaryType: markdownService.detectPrimaryType(in: body),
            snippetLanguageHint: markdownService.detectSnippetLanguageHint(in: body),
            createdAt: createdAt,
            updatedAt: updatedAt,
            sortDate: updatedAt,
            isPinned: isPinned,
            isFavorite: isFavorite,
            isArchived: false,
            isDeleted: false,
            deletedAt: nil,
            version: 1
        )
    }
}

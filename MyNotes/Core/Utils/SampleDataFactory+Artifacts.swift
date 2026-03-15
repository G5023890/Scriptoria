import Foundation

extension SampleDataFactory {
    static let sampleAttachmentResourceName = "DataModel-v1"
    static let sampleAttachmentResourceExtension = "pdf"
    static let sampleAttachmentResourceSubdirectory = "SampleData"
    static let sampleAttachmentRelativePath = "attachments/note_note-attachments/attachment_attachment-design-doc.pdf"

    static func makeAttachment(now: Date) -> Attachment {
        Attachment(
            id: AttachmentID(rawValue: "attachment-design-doc"),
            noteID: NoteID(rawValue: "note-attachments"),
            fileName: "attachment_attachment-design-doc.pdf",
            originalFileName: "DataModel-v1.pdf",
            mimeType: "application/pdf",
            category: .pdf,
            relativePath: sampleAttachmentRelativePath,
            fileSize: 234_512,
            checksum: "demo-checksum",
            width: nil,
            height: nil,
            duration: nil,
            pageCount: 12,
            createdAt: now,
            updatedAt: now,
            isArchived: false,
            isDeleted: false,
            deletedAt: nil,
            version: 1
        )
    }

    static func makeSnippet(now: Date) -> NoteSnippet {
        NoteSnippet(
            id: "snippet-window-lifecycle",
            noteID: NoteID(rawValue: "note-swift-snippet"),
            language: "swift",
            title: "Quick capture presenter",
            snippetDescription: nil,
            code: """
            @MainActor
            func presentQuickCapture() {
                coordinator.isQuickCapturePresented = true
            }
            """,
            startOffset: 54,
            endOffset: 157,
            sourceType: .automatic,
            createdAt: now,
            updatedAt: now,
            isArchived: false,
            isDeleted: false,
            deletedAt: nil,
            version: 1
        )
    }
}

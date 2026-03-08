import SwiftUI

struct NoteMetadataSectionsView: View {
    let attachmentItems: [AttachmentItem]
    let snippetItems: [SnippetItem]
    let allowsAttachmentRemoval: Bool
    let syntaxHighlightService: any SyntaxHighlightService
    let onPreviewAttachment: (Attachment) -> Void
    let onOpenAttachment: (Attachment) -> Void
    let onRemoveAttachment: (Attachment) -> Void
    let onCopySnippet: (NoteSnippet) -> Void
    let onEditSnippet: ((NoteSnippet) -> Void)?
    let onRemoveSnippet: ((NoteSnippet) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            if !attachmentItems.isEmpty {
                AttachmentSectionView(
                    title: "",
                    attachments: attachmentItems,
                    emptyText: "No attachments for this note yet.",
                    allowsRemoval: allowsAttachmentRemoval,
                    syntaxHighlightService: syntaxHighlightService,
                    onPreview: onPreviewAttachment,
                    onOpen: onOpenAttachment,
                    onRemove: allowsAttachmentRemoval ? onRemoveAttachment : nil,
                    headerAction: nil
                )
            }

            if !snippetItems.isEmpty {
                SnippetSectionView(
                    title: "",
                    snippets: snippetItems,
                    emptyText: nil,
                    syntaxHighlightService: syntaxHighlightService,
                    onCopy: onCopySnippet,
                    onEdit: onEditSnippet,
                    onRemove: onRemoveSnippet
                )
            }
        }
    }
}

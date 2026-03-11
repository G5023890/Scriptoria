import SwiftUI

struct NoteMetadataSectionsView: View {
    let toDoItems: [NoteToDoItem]
    let deletedToDoItems: [NoteToDoItem]
    let attachmentItems: [AttachmentItem]
    let snippetItems: [SnippetItem]
    let allowsTaskMutation: Bool
    let allowsTaskCompletionToggle: Bool
    let allowsAttachmentRemoval: Bool
    let focusedToDoID: ToDoID?
    let onToggleToDoCompletion: (ToDo) async -> Void
    let onEditToDo: (ToDo) -> Void
    let onDeleteToDo: (ToDo) async -> Void
    let onRemoveToDo: (ToDo) async -> Void
    let onRestoreToDo: (ToDo) async -> Void
    let onMoveToDo: (ToDo, NoteTaskMoveDirection) async -> Void
    let onFocusRequest: ((ToDoID) -> Void)?
    let syntaxHighlightService: any SyntaxHighlightService
    let onPreviewAttachment: (Attachment) -> Void
    let onOpenAttachment: (Attachment) -> Void
    let onRemoveAttachment: (Attachment) -> Void
    let onCopySnippet: (NoteSnippet) -> Void
    let onPreviewSnippet: ((NoteSnippet) -> Void)?
    let onEditSnippet: ((NoteSnippet) -> Void)?
    let onRemoveSnippet: ((NoteSnippet) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            if !toDoItems.isEmpty || !deletedToDoItems.isEmpty {
                NoteTasksSectionView(
                    items: toDoItems,
                    deletedItems: deletedToDoItems,
                    allowsMutation: allowsTaskMutation,
                    allowsCompletionToggle: allowsTaskCompletionToggle,
                    focusedToDoID: focusedToDoID,
                    onToggleComplete: onToggleToDoCompletion,
                    onEditRequested: onEditToDo,
                    onDelete: onDeleteToDo,
                    onRemove: onRemoveToDo,
                    onRestore: onRestoreToDo,
                    onMove: onMoveToDo,
                    onFocusRequest: onFocusRequest
                )
            }

            if !snippetItems.isEmpty {
                SnippetSectionView(
                    title: "",
                    snippets: snippetItems,
                    emptyText: nil,
                    syntaxHighlightService: syntaxHighlightService,
                    showsInlineCode: false,
                    onCopy: onCopySnippet,
                    onPreviewSnippet: onPreviewSnippet,
                    onEdit: onEditSnippet,
                    onRemove: onRemoveSnippet
                )
            }

            if !attachmentItems.isEmpty {
                AttachmentSectionView(
                    title: "",
                    attachments: attachmentItems,
                    emptyText: "No attachments for this note yet.",
                    allowsRemoval: allowsAttachmentRemoval,
                    onPreview: onPreviewAttachment,
                    onOpen: onOpenAttachment,
                    onRemove: allowsAttachmentRemoval ? onRemoveAttachment : nil,
                    headerAction: nil
                )
            }
        }
    }
}

import SwiftUI

let noteArchiveBottomAnchorID = "note-archive-bottom-anchor"

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
    let onArchiveRevealRequest: (() -> Void)?
    let syntaxHighlightService: any SyntaxHighlightService
    let onPreviewAttachment: (Attachment) -> Void
    let onOpenAttachment: (Attachment) -> Void
    let onArchiveAttachment: ((Attachment) -> Void)?
    let onRemoveAttachment: (Attachment) -> Void
    let onCopySnippet: (NoteSnippet) -> Void
    let onPreviewSnippet: ((NoteSnippet) -> Void)?
    let onArchiveSnippet: ((NoteSnippet) -> Void)?
    let onEditSnippet: ((NoteSnippet) -> Void)?
    let onRemoveSnippet: ((NoteSnippet) -> Void)?

    private var activeToDoItems: [NoteToDoItem] {
        toDoItems.filter { !$0.isArchived && !$0.isDeleted }
    }

    private var archivedToDoItems: [NoteToDoItem] {
        toDoItems.filter { $0.isArchived && !$0.isDeleted }
    }

    private var activeSnippetItems: [SnippetItem] {
        snippetItems.filter { !$0.isArchived }
    }

    private var archivedSnippetItems: [SnippetItem] {
        snippetItems.filter(\.isArchived)
    }

    private var activeAttachmentItems: [AttachmentItem] {
        attachmentItems.filter { !$0.isArchived }
    }

    private var archivedAttachmentItems: [AttachmentItem] {
        attachmentItems.filter(\.isArchived)
    }

    private var archivedItems: [ArchivedNoteItem] {
        (archivedToDoItems.map(ArchivedNoteItem.task) +
         archivedSnippetItems.map(ArchivedNoteItem.snippet) +
         archivedAttachmentItems.map(ArchivedNoteItem.attachment))
            .sorted(by: ArchivedNoteItem.sortNewestFirst)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            if !activeToDoItems.isEmpty || !deletedToDoItems.isEmpty {
                NoteTasksSectionView(
                    items: activeToDoItems,
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

            if !activeSnippetItems.isEmpty {
                SnippetSectionView(
                    title: "",
                    snippets: activeSnippetItems,
                    emptyText: nil,
                    syntaxHighlightService: syntaxHighlightService,
                    showsInlineCode: false,
                    onCopy: onCopySnippet,
                    onPreviewSnippet: onPreviewSnippet,
                    onArchive: onArchiveSnippet,
                    onEdit: onEditSnippet,
                    onRemove: onRemoveSnippet
                )
            }

            if !activeAttachmentItems.isEmpty {
                AttachmentSectionView(
                    title: "",
                    attachments: activeAttachmentItems,
                    emptyText: "No attachments for this note yet.",
                    allowsRemoval: allowsAttachmentRemoval,
                    onPreview: onPreviewAttachment,
                    onOpen: onOpenAttachment,
                    onArchive: onArchiveAttachment,
                    onRemove: allowsAttachmentRemoval ? onRemoveAttachment : nil,
                    headerAction: nil
                )
            }

            if !archivedItems.isEmpty {
                ArchivedNoteSectionView(
                    items: archivedItems,
                    allowsTaskMutation: allowsTaskMutation,
                    allowsTaskCompletionToggle: allowsTaskCompletionToggle,
                    allowsAttachmentRemoval: allowsAttachmentRemoval,
                    focusedToDoID: focusedToDoID,
                    onToggleToDoCompletion: onToggleToDoCompletion,
                    onEditToDo: onEditToDo,
                    onDeleteToDo: onDeleteToDo,
                    onRemoveToDo: onRemoveToDo,
                    onRestoreToDo: onRestoreToDo,
                    onPreviewAttachment: onPreviewAttachment,
                    onOpenAttachment: onOpenAttachment,
                    onRemoveAttachment: onRemoveAttachment,
                    onCopySnippet: onCopySnippet,
                    onPreviewSnippet: onPreviewSnippet,
                    onEditSnippet: onEditSnippet,
                    onRemoveSnippet: onRemoveSnippet,
                    onFocusRequest: onFocusRequest,
                    onArchiveRevealRequest: onArchiveRevealRequest,
                    syntaxHighlightService: syntaxHighlightService
                )
            }
        }
    }
}

private enum ArchivedNoteItem: Identifiable {
    case task(NoteToDoItem)
    case snippet(SnippetItem)
    case attachment(AttachmentItem)

    var id: String {
        switch self {
        case .task(let item):
            return "task:\(item.id.rawValue)"
        case .snippet(let item):
            return "snippet:\(item.id)"
        case .attachment(let item):
            return "attachment:\(item.id.rawValue)"
        }
    }

    var updatedAt: Date {
        switch self {
        case .task(let item):
            return item.todo.updatedAt
        case .snippet(let item):
            return item.snippet.updatedAt
        case .attachment(let item):
            return item.attachment.updatedAt
        }
    }

    static func sortNewestFirst(lhs: ArchivedNoteItem, rhs: ArchivedNoteItem) -> Bool {
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        return lhs.id < rhs.id
    }
}

private struct ArchivedNoteSectionView: View {
    @State private var isExpanded = false
    @State private var expandedTaskIDs: Set<ToDoID> = []
    @State private var activePreviewSnippetItem: SnippetItem?

    let items: [ArchivedNoteItem]
    let allowsTaskMutation: Bool
    let allowsTaskCompletionToggle: Bool
    let allowsAttachmentRemoval: Bool
    let focusedToDoID: ToDoID?
    let onToggleToDoCompletion: (ToDo) async -> Void
    let onEditToDo: (ToDo) -> Void
    let onDeleteToDo: (ToDo) async -> Void
    let onRemoveToDo: (ToDo) async -> Void
    let onRestoreToDo: (ToDo) async -> Void
    let onPreviewAttachment: (Attachment) -> Void
    let onOpenAttachment: (Attachment) -> Void
    let onRemoveAttachment: (Attachment) -> Void
    let onCopySnippet: (NoteSnippet) -> Void
    let onPreviewSnippet: ((NoteSnippet) -> Void)?
    let onEditSnippet: ((NoteSnippet) -> Void)?
    let onRemoveSnippet: ((NoteSnippet) -> Void)?
    let onFocusRequest: ((ToDoID) -> Void)?
    let onArchiveRevealRequest: (() -> Void)?
    let syntaxHighlightService: any SyntaxHighlightService

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            Button(action: toggleSection) {
                HStack(spacing: AppSpacing.small) {
                    Text("Архив")
                        .font(AppTypography.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    InfoBadge(text: "\(items.count)")
                    Spacer()
                    Image(systemName: isExpanded ? AppIcons.chevronUp : AppIcons.chevronDown)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    ForEach(items) { item in
                        row(for: item)
                            .id(item.id)
                    }
                    Color.clear
                        .frame(height: 1)
                        .id(noteArchiveBottomAnchorID)
                }
            }
        }
        .onAppear {
            focusArchivedTaskIfNeeded()
        }
        .onChange(of: focusedToDoID) { _, _ in
            focusArchivedTaskIfNeeded()
        }
        .sheet(item: $activePreviewSnippetItem) { item in
            SnippetInlinePreviewSheet(
                item: item,
                syntaxHighlightService: syntaxHighlightService,
                onCopy: {
                    onCopySnippet(item.snippet)
                }
            )
        }
    }

    @ViewBuilder
    private func row(for item: ArchivedNoteItem) -> some View {
        switch item {
        case .task(let toDoItem):
            NoteTaskRowView(
                item: toDoItem,
                isFocused: focusedToDoID == toDoItem.id,
                isExpanded: expandedTaskIDs.contains(toDoItem.id),
                allowsMutation: allowsTaskMutation,
                allowsCompletionToggle: allowsTaskCompletionToggle,
                onToggleComplete: asyncAction {
                    await onToggleToDoCompletion(toDoItem.todo)
                },
                onToggleExpansion: toDoItem.isCompleted ? {
                    toggleTaskExpansion(for: toDoItem.id)
                } : nil,
                onEdit: allowsTaskMutation ? {
                    onEditToDo(toDoItem.todo)
                } : nil,
                onDelete: allowsTaskMutation ? asyncAction {
                    await onDeleteToDo(toDoItem.todo)
                } : nil,
                onRemove: nil,
                onRestore: nil
            )

        case .snippet(let snippetItem):
            let allowsMutation = snippetItem.snippet.sourceType == .manual
            SnippetRowView(
                item: snippetItem,
                showsInlineCode: false,
                onPreview: {
                    if let onPreviewSnippet {
                        onPreviewSnippet(snippetItem.snippet)
                    } else {
                        activePreviewSnippetItem = snippetItem
                    }
                },
                onCopy: { onCopySnippet(snippetItem.snippet) },
                onArchive: nil,
                onEdit: allowsMutation ? onEditSnippet.map { action in
                    { action(snippetItem.snippet) }
                } : nil,
                onRemove: allowsMutation ? onRemoveSnippet.map { action in
                    { action(snippetItem.snippet) }
                } : nil
            )

        case .attachment(let attachmentItem):
            AttachmentRowView(
                item: attachmentItem,
                allowsRemoval: allowsAttachmentRemoval,
                onPreview: { onPreviewAttachment(attachmentItem.attachment) },
                onOpen: { onOpenAttachment(attachmentItem.attachment) },
                onArchive: nil,
                onRemove: allowsAttachmentRemoval ? { onRemoveAttachment(attachmentItem.attachment) } : nil
            )
        }
    }

    private func toggleSection() {
        isExpanded.toggle()
        guard isExpanded else { return }

        DispatchQueue.main.async {
            onArchiveRevealRequest?()
        }
    }

    private func toggleTaskExpansion(for toDoID: ToDoID) {
        if expandedTaskIDs.contains(toDoID) {
            expandedTaskIDs.remove(toDoID)
        } else {
            expandedTaskIDs.insert(toDoID)
        }
    }

    private func asyncAction(_ operation: @escaping () async -> Void) -> () -> Void {
        {
            Task<Void, Never> {
                await operation()
            }
        }
    }

    private func focusArchivedTaskIfNeeded() {
        guard let focusedToDoID else { return }
        let archivedTaskIDs = Set(items.compactMap { item -> ToDoID? in
            if case .task(let taskItem) = item {
                return taskItem.id
            }
            return nil
        })

        guard archivedTaskIDs.contains(focusedToDoID) else { return }

        if !isExpanded {
            isExpanded = true
        }

        DispatchQueue.main.async {
            onFocusRequest?(focusedToDoID)
        }
    }
}

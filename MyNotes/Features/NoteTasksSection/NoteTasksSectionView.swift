import SwiftUI

enum NoteTaskMoveDirection: Equatable {
    case up
    case down
}

struct NoteTasksSectionView: View {
    @State private var expandedCompletedIDs: Set<ToDoID> = []

    let items: [NoteToDoItem]
    let deletedItems: [NoteToDoItem]
    let allowsMutation: Bool
    let allowsCompletionToggle: Bool
    let focusedToDoID: ToDoID?
    let onToggleComplete: (ToDo) async -> Void
    let onEditRequested: (ToDo) -> Void
    let onDelete: (ToDo) async -> Void
    let onRemove: (ToDo) async -> Void
    let onRestore: (ToDo) async -> Void
    let onMove: (ToDo, NoteTaskMoveDirection) async -> Void
    let onFocusRequest: ((ToDoID) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                ForEach(items) { item in
                    NoteTaskRowView(
                        item: item,
                        isFocused: focusedToDoID == item.id,
                        isExpanded: expandedCompletedIDs.contains(item.id),
                        allowsMutation: allowsMutation,
                        allowsCompletionToggle: allowsCompletionToggle,
                        onToggleComplete: asyncAction {
                            await onToggleComplete(item.todo)
                        },
                        onToggleExpansion: item.isCompleted ? {
                            toggleExpansion(for: item.id)
                        } : nil,
                        onEdit: allowsMutation ? {
                            onEditRequested(item.todo)
                        } : nil,
                        onDelete: allowsMutation ? asyncAction {
                            await onDelete(item.todo)
                        } : nil,
                        onRemove: nil,
                        onRestore: nil
                    )
                    .id(item.id)
                }
            }

            if !deletedItems.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                    Text("Recently Deleted")
                        .font(AppTypography.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(deletedItems) { item in
                        NoteTaskRowView(
                            item: item,
                            isFocused: focusedToDoID == item.id,
                            isExpanded: false,
                            allowsMutation: allowsMutation,
                            allowsCompletionToggle: false,
                            onToggleComplete: {},
                            onToggleExpansion: nil,
                            onEdit: allowsMutation ? {
                                onEditRequested(item.todo)
                            } : nil,
                            onDelete: nil,
                            onRemove: allowsMutation ? asyncAction {
                                await onRemove(item.todo)
                            } : nil,
                            onRestore: allowsMutation ? asyncAction {
                                await onRestore(item.todo)
                            } : nil
                        )
                        .id(item.id)
                    }
                }
            }
        }
        .onAppear {
            requestFocusIfNeeded()
        }
        .onChange(of: focusedToDoID) { _, _ in
            requestFocusIfNeeded()
        }
    }

    private func requestFocusIfNeeded() {
        guard let focusedToDoID else { return }
        let allIDs = items.map(\.id) + deletedItems.map(\.id)
        guard allIDs.contains(focusedToDoID) else { return }
        onFocusRequest?(focusedToDoID)
    }

    private func toggleExpansion(for toDoID: ToDoID) {
        if expandedCompletedIDs.contains(toDoID) {
            expandedCompletedIDs.remove(toDoID)
        } else {
            expandedCompletedIDs.insert(toDoID)
        }
    }

    private func asyncAction(_ operation: @escaping () async -> Void) -> () -> Void {
        {
            Task<Void, Never> {
                await operation()
            }
        }
    }
}

private struct NoteTaskRowView: View {
    let item: NoteToDoItem
    let isFocused: Bool
    let isExpanded: Bool
    let allowsMutation: Bool
    let allowsCompletionToggle: Bool
    let onToggleComplete: () -> Void
    let onToggleExpansion: (() -> Void)?
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    let onRemove: (() -> Void)?
    let onRestore: (() -> Void)?

    private var isExpandable: Bool {
        item.isCompleted && !item.isDeleted
    }

    private var isCollapsed: Bool {
        isExpandable && !isExpanded
    }

    private var showsActions: Bool {
        onToggleExpansion != nil ||
        onEdit != nil ||
        onDelete != nil ||
        onRemove != nil ||
        onRestore != nil ||
        (allowsCompletionToggle && !item.isDeleted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: AppSpacing.small) {
                categoryChip(systemImage: AppIcons.tasks)

                textContent

                if showsActions {
                    Spacer(minLength: AppSpacing.small)

                    HStack(spacing: AppSpacing.small) {
                        if let onToggleExpansion, isExpandable {
                            iconButton(
                                systemImage: isExpanded ? AppIcons.chevronUp : AppIcons.chevronDown,
                                accessibilityLabel: isExpanded ? "Collapse completed task" : "Expand completed task",
                                action: onToggleExpansion
                            )
                        }
                        if allowsCompletionToggle && !item.isDeleted {
                            iconButton(
                                systemImage: item.isCompleted ? AppIcons.taskMarkOpen : AppIcons.taskMarkCompleted,
                                accessibilityLabel: item.isCompleted ? "Mark Open" : "Complete",
                                action: onToggleComplete
                            )
                        }
                        if let onEdit {
                            iconButton(
                                systemImage: AppIcons.edit,
                                accessibilityLabel: "Edit",
                                action: onEdit
                            )
                        }
                        if let onRestore {
                            Button("Restore", action: onRestore)
                                .buttonStyle(.borderless)
                        }
                        if let onDelete {
                            Button("Remove", role: .destructive, action: onDelete)
                                .buttonStyle(.borderless)
                        }
                        if let onRemove {
                            Button("Remove", role: .destructive, action: onRemove)
                                .buttonStyle(.borderless)
                        }
                    }
                    .font(AppTypography.caption)
                    .fixedSize()
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isFocused ? AppColors.chipBackground.opacity(1.5) : AppColors.chipBackground)
        )
        .overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.45))
            }
        }
        .opacity(item.isDeleted ? 0.78 : 1)
    }

    @ViewBuilder
    private var textContent: some View {
        if isCollapsed {
            collapsedText
        } else {
            expandedText
        }
    }

    private var expandedText: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xSmall) {
                Text(item.title)
                    .font(AppTypography.bodySemibold)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isDeleted ? .secondary : .primary)
                if item.isCompleted {
                    Text("Done")
                        .font(AppTypography.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
            if !item.details.isEmpty {
                Text(item.details)
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            if let dueText = item.dueText {
                Text(dueText)
                    .font(AppTypography.caption)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
            }
        }
    }

    private var collapsedText: some View {
        collapsedSummary
            .lineLimit(2)
    }

    private var collapsedSummary: Text {
        var summary = Text(item.title)
            .font(AppTypography.bodySemibold)
            .strikethrough(item.isCompleted)
            .foregroundStyle(item.isDeleted ? .secondary : .primary)

        if item.isCompleted {
            summary = summary + Text(" Done")
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(.green)
        }

        if !item.details.isEmpty {
            summary = summary + Text(" • \(item.details)")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
        }

        if let dueText = item.dueText {
            summary = summary + Text(" • \(dueText)")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
        }

        return summary
    }

    private func categoryChip(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.08))
            )
    }

    private func iconButton(
        systemImage: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct ToDoEditorSheet: View {
    @State private var draft: ToDoDraft
    @State private var hasDueDate: Bool

    let onCancel: () -> Void
    let onSave: (ToDoDraft) -> Void

    init(
        draft: ToDoDraft,
        onCancel: @escaping () -> Void,
        onSave: @escaping (ToDoDraft) -> Void
    ) {
        _draft = State(initialValue: draft)
        _hasDueDate = State(initialValue: draft.dueDate != nil)
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(draft.toDoID == nil ? "New Task" : "Edit Task")
                .font(AppTypography.section)

            TextField("Title", text: $draft.title)
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $draft.details)
                .font(.system(.body, design: .default))
                .frame(minHeight: 120)
                .modifier(PanelSurfaceModifier())

            Toggle("Set due date", isOn: Binding(
                get: { hasDueDate },
                set: { newValue in
                    hasDueDate = newValue
                    if newValue {
                        draft.dueDate = draft.dueDate ?? Date()
                    } else {
                        draft.dueDate = nil
                        draft.hasTimeComponent = false
                    }
                }
            ))

            if hasDueDate {
                Toggle("Specify time", isOn: $draft.hasTimeComponent)

                DatePicker(
                    "Due Date",
                    selection: Binding(
                        get: { draft.dueDate ?? Date() },
                        set: { draft.dueDate = $0 }
                    ),
                    displayedComponents: [.date]
                )

                if draft.hasTimeComponent {
                    DatePicker(
                        "Time",
                        selection: Binding(
                            get: { draft.dueDate ?? Date() },
                            set: { draft.dueDate = $0 }
                        ),
                        displayedComponents: [.hourAndMinute]
                    )
                }
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save") {
                    onSave(draft)
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(AppSpacing.large)
        .frame(minWidth: 420, minHeight: 420)
    }
}

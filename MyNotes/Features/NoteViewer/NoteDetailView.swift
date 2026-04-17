import Observation
import SwiftUI
import UniformTypeIdentifiers

struct NoteDetailView: View {
    @Bindable var viewModel: NoteDetailViewModel
    let environment: AppEnvironment
    let coordinator: AppCoordinator
    let onNoteChanged: @MainActor (NoteID) async -> Void

    @State private var editorViewModel: NoteEditorViewModel?

    var body: some View {
        Group {
            if let snapshot = viewModel.snapshot {
                detailShell(snapshot: snapshot)
            } else {
                EmptySelectionView(coordinator: coordinator)
            }
        }
        .task(id: editorPreparationTaskID) {
            await prepareEditor()
        }
    }

    private var editorPreparationTaskID: String {
        let noteID = viewModel.snapshot?.note.id.rawValue ?? "none"
        return "\(noteID)::\(viewModel.mode.rawValue)"
    }

    private func detailShell(snapshot: NoteSnapshot) -> some View {
        let isDeleted = snapshot.note.isDeleted
        let effectiveMode: NoteDetailMode = isDeleted ? .read : viewModel.mode
        let readToDoItems = editorViewModel?.toDoItems ?? viewModel.toDoItems
        let readDeletedToDoItems: [NoteToDoItem] = effectiveMode == .read
            ? []
            : (editorViewModel?.deletedToDoItems ?? viewModel.deletedToDoItems)
        let readAttachmentItems = editorViewModel?.attachmentItems ?? viewModel.attachmentItems
        let readSnippetItems = editorViewModel?.snippetItems ?? viewModel.snippetItems
        let headerModeBinding = Binding<NoteDetailMode>(
            get: { isDeleted ? .read : viewModel.mode },
            set: { nextMode in
                guard !isDeleted else { return }
                viewModel.mode = nextMode
                guard nextMode == .read else { return }

                Task {
                    await viewModel.reloadCurrent()
                }
            }
        )

        let content = AnyView(Group {
            if effectiveMode == .read {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: AppSpacing.medium) {
                            if snapshot.note.bodyMarkdown.isEmpty {
                                ContentUnavailableView(
                                    "No Content",
                                    systemImage: "doc.text",
                                    description: Text("Switch to Edit mode to start writing.")
                                )
                                .frame(maxWidth: .infinity)
                            } else {
                                NoteRenderedContentView(markdown: snapshot.note.bodyMarkdown)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            NoteMetadataSectionsView(
                                toDoItems: readToDoItems,
                                deletedToDoItems: readDeletedToDoItems,
                                attachmentItems: readAttachmentItems,
                                snippetItems: readSnippetItems,
                                allowsTaskMutation: false,
                                allowsTaskCompletionToggle: !snapshot.note.isDeleted,
                                allowsAttachmentRemoval: false,
                                focusedToDoID: coordinator.selectedToDoID,
                                onToggleToDoCompletion: { todo in
                                    await viewModel.toggleToDoCompletion(todo)
                                    await onNoteChanged(snapshot.note.id)
                                },
                                onEditToDo: viewModel.presentEditToDoSheet,
                                onDeleteToDo: { todo in
                                    await viewModel.deleteToDo(todo)
                                    await onNoteChanged(snapshot.note.id)
                                },
                                onRemoveToDo: { todo in
                                    await viewModel.removeToDo(todo)
                                    await onNoteChanged(snapshot.note.id)
                                },
                                onRestoreToDo: { todo in
                                    await viewModel.restoreToDo(todo)
                                    await onNoteChanged(snapshot.note.id)
                                },
                                onMoveToDo: { todo, direction in
                                    await viewModel.moveToDo(todo, direction: direction)
                                    await onNoteChanged(snapshot.note.id)
                                },
                                onFocusRequest: { toDoID in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        proxy.scrollTo(toDoID, anchor: .center)
                                    }
                                },
                                onArchiveRevealRequest: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        proxy.scrollTo(noteArchiveBottomAnchorID, anchor: .bottom)
                                    }
                                },
                                syntaxHighlightService: viewModel.syntaxHighlightService,
                                onPreviewAttachment: viewModel.previewAttachment,
                                onOpenAttachment: viewModel.openAttachment,
                                onEditAttachment: nil,
                                onArchiveAttachment: nil,
                                onRemoveAttachment: { _ in },
                                onCopySnippet: viewModel.copySnippet,
                                onPreviewSnippet: viewModel.previewSnippet,
                                onArchiveSnippet: nil,
                                onEditSnippet: nil,
                                onRemoveSnippet: nil
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else if let editorViewModel {
                NoteEditorPane(
                    viewModel: editorViewModel,
                    mode: viewModel.mode,
                    focusedToDoID: coordinator.selectedToDoID
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        })

        let header = AnyView(NoteDetailHeaderView(
            snapshot: snapshot,
            mode: headerModeBinding,
            titleBinding: titleBinding(for: snapshot, mode: effectiveMode),
            availableLabels: effectiveMode == .read ? viewModel.availableLabels : (editorViewModel?.availableLabels ?? []),
            selectedLabels: effectiveMode == .read ? snapshot.labels : (editorViewModel?.draft?.labels ?? snapshot.labels),
            newLabelName: newLabelBinding(),
            saveStatusText: editorViewModel?.lastSavedText,
            isSaving: editorViewModel?.isSaving ?? false,
            isCreatingLabel: effectiveMode == .read ? viewModel.isCreatingLabel : (editorViewModel?.isCreatingLabel ?? false),
            onToggleLabel: { label in
                if effectiveMode == .read {
                    Task {
                        await viewModel.toggleLabel(label)
                        await onNoteChanged(snapshot.note.id)
                    }
                } else {
                    editorViewModel?.toggleLabel(label)
                }
            },
            onCreateLabel: {
                if effectiveMode == .read {
                    Task {
                        await viewModel.createLabel()
                        await onNoteChanged(snapshot.note.id)
                    }
                } else {
                    Task {
                        await editorViewModel?.createLabel()
                    }
                }
            },
            onAddTask: {
                if effectiveMode == .read {
                    viewModel.presentNewToDoSheet()
                } else {
                    editorViewModel?.presentNewToDoSheet()
                }
            },
            onAddSnippet: {
                if effectiveMode == .read {
                    viewModel.presentManualSnippetSheet()
                } else {
                    editorViewModel?.presentManualSnippetSheet()
                }
            },
            onAddAttachment: {
                if effectiveMode == .read {
                    viewModel.presentAttachmentImporter()
                } else {
                    editorViewModel?.presentAttachmentImporter()
                }
            },
            onDelete: {
                Task {
                    await viewModel.deleteCurrentNote()
                    await onNoteChanged(snapshot.note.id)
                }
            },
            onRestore: {
                Task {
                    await viewModel.restoreCurrentNote()
                    await onNoteChanged(snapshot.note.id)
                }
            },
            onTogglePin: {
                Task {
                    await viewModel.togglePin()
                    await onNoteChanged(snapshot.note.id)
                }
            },
            onToggleFavorite: {
                Task {
                    await viewModel.toggleFavorite()
                    await onNoteChanged(snapshot.note.id)
                }
            }
        ))

        let attachmentImporterBinding = Binding(
            get: {
                effectiveMode == .read
                    ? viewModel.isImportingAttachments
                    : (editorViewModel?.isImportingAttachments ?? false)
            },
            set: { newValue in
                if !newValue {
                    if effectiveMode == .read {
                        viewModel.isImportingAttachments = false
                    } else {
                        editorViewModel?.isImportingAttachments = false
                    }
                }
            }
        )

        let toDoSheetBinding = Binding<ToDoDraft?>(
            get: { editorViewModel?.activeToDoDraft ?? viewModel.activeToDoDraft },
            set: { _ in
                editorViewModel?.dismissToDoSheet()
                viewModel.dismissToDoSheet()
            }
        )

        let attachmentPreviewBinding = Binding(
            get: { editorViewModel?.activeAttachmentPreview ?? viewModel.activeAttachmentPreview },
            set: { (_: AttachmentPreviewState?) in
                editorViewModel?.dismissAttachmentPreview()
                viewModel.dismissAttachmentPreview()
            }
        )

        let attachmentEditBinding = Binding<AttachmentEditDraft?>(
            get: { editorViewModel?.activeAttachmentEditDraft ?? viewModel.activeAttachmentEditDraft },
            set: { _ in
                editorViewModel?.dismissAttachmentSheet()
                viewModel.dismissAttachmentSheet()
            }
        )

        let snippetPreviewBinding = Binding<NoteSnippet?>(
            get: { viewModel.activeSnippetPreview },
            set: { _ in
                viewModel.dismissSnippetPreview()
            }
        )

        let manualSnippetSheetBinding = Binding(
            get: {
                effectiveMode == .read
                    ? viewModel.isShowingManualSnippetSheet
                    : (editorViewModel?.isShowingManualSnippetSheet ?? false)
            },
            set: { newValue in
                if !newValue {
                    if effectiveMode == .read {
                        viewModel.isShowingManualSnippetSheet = false
                    } else {
                        editorViewModel?.isShowingManualSnippetSheet = false
                    }
                }
            }
        )

        let baseShell = NoteDetailShellBody(header: header, content: content)

        let shellWithImporter = baseShell.fileImporter(
            isPresented: attachmentImporterBinding,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task {
                    if effectiveMode == .read {
                        let didImport = await self.viewModel.importAttachments(from: urls)
                        if didImport {
                            await onNoteChanged(snapshot.note.id)
                        }
                    } else if let editorViewModel {
                        await editorViewModel.importAttachments(from: urls)
                    }
                }
            case .failure(let error):
                if effectiveMode == .read {
                    viewModel.errorMessage = "Import failed: \(error.localizedDescription)"
                } else {
                    editorViewModel?.errorMessage = "Import failed: \(error.localizedDescription)"
                }
            }
        }

        let shellWithTaskSheet = shellWithImporter.sheet(item: toDoSheetBinding) { draft in
            ToDoEditorSheet(
                draft: draft,
                onCancel: {
                    editorViewModel?.dismissToDoSheet()
                    viewModel.dismissToDoSheet()
                },
                onSave: { draft in
                    Task {
                        if effectiveMode == .read {
                            if draft.toDoID == nil {
                                await viewModel.createToDo(draft: draft)
                            } else {
                                await viewModel.updateToDo(draft: draft)
                            }
                        } else if let editorViewModel {
                            if draft.toDoID == nil {
                                await editorViewModel.createToDo(draft: draft)
                            } else {
                                await editorViewModel.updateToDo(draft: draft)
                            }
                        }
                        editorViewModel?.dismissToDoSheet()
                        viewModel.dismissToDoSheet()
                        await onNoteChanged(snapshot.note.id)
                    }
                }
            )
        }

        let shellWithAttachmentPreview = shellWithTaskSheet.sheet(item: attachmentPreviewBinding) { preview in
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack {
                    Text(preview.title)
                        .font(AppTypography.section)
                    Spacer()
                    Button("Copy") {
                        if effectiveMode == .read {
                            viewModel.copyAttachmentPreview(preview)
                        } else {
                            editorViewModel?.copyAttachmentPreview(preview)
                        }
                    }
                    Button("Done") {
                        editorViewModel?.dismissAttachmentPreview()
                        viewModel.dismissAttachmentPreview()
                    }
                }

                QuickLookPreviewSheet(url: preview.url)
                    #if os(macOS)
                    .frame(minWidth: 680, minHeight: 520)
                    #else
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    #endif
            }
            .padding(AppSpacing.large)
        }

        let shellWithAttachmentEdit = shellWithAttachmentPreview.sheet(item: attachmentEditBinding) { draft in
            AttachmentEditSheet(
                draft: Binding(
                    get: { attachmentEditBinding.wrappedValue ?? draft },
                    set: { nextDraft in
                        if effectiveMode == .read {
                            viewModel.activeAttachmentEditDraft = nextDraft
                        } else {
                            editorViewModel?.activeAttachmentEditDraft = nextDraft
                        }
                    }
                ),
                isSaving: effectiveMode == .read
                    ? viewModel.isSavingAttachment
                    : (editorViewModel?.isSavingAttachment ?? false),
                onCancel: {
                    editorViewModel?.dismissAttachmentSheet()
                    viewModel.dismissAttachmentSheet()
                },
                onSave: {
                    Task {
                        let currentDraft = attachmentEditBinding.wrappedValue ?? draft
                        if effectiveMode == .read {
                            await viewModel.updateAttachment(draft: currentDraft)
                            await onNoteChanged(snapshot.note.id)
                        } else if let editorViewModel {
                            await editorViewModel.updateAttachment(draft: currentDraft)
                        }
                    }
                }
            )
        }

        let shellWithSnippetPreview = shellWithAttachmentEdit.sheet(item: snippetPreviewBinding) { snippet in
            SnippetPreviewSheet(
                snippet: snippet,
                syntaxHighlightService: viewModel.syntaxHighlightService,
                onCopy: {
                    viewModel.copySnippet(snippet)
                }
            )
        }

        let shell = shellWithSnippetPreview.sheet(isPresented: manualSnippetSheetBinding) {
            if effectiveMode == .read {
                ManualSnippetSheet(
                    draft: Binding(
                        get: { viewModel.manualSnippetDraft },
                        set: { viewModel.manualSnippetDraft = $0 }
                    ),
                    isSaving: viewModel.isSavingManualSnippet,
                    isEditing: false,
                    onCancel: {
                        viewModel.isShowingManualSnippetSheet = false
                    },
                    onSave: {
                        Task {
                            let didCreate = await viewModel.createManualSnippet()
                            if didCreate {
                                await onNoteChanged(snapshot.note.id)
                            }
                        }
                    }
                )
            } else if let editorViewModel {
                ManualSnippetSheet(
                    draft: Binding(
                        get: { editorViewModel.manualSnippetDraft },
                        set: { editorViewModel.manualSnippetDraft = $0 }
                    ),
                    isSaving: editorViewModel.isSavingManualSnippet,
                    isEditing: editorViewModel.isEditingManualSnippet,
                    onCancel: {
                        editorViewModel.isShowingManualSnippetSheet = false
                    },
                    onSave: {
                        Task {
                            await editorViewModel.createManualSnippet()
                        }
                    }
                )
            }
        }
        .alert(
            "Action Failed",
            isPresented: Binding(
                get: {
                    (editorViewModel?.errorMessage?.isEmpty == false) ||
                    (viewModel.errorMessage?.isEmpty == false)
                },
                set: { newValue in
                    if !newValue {
                        editorViewModel?.clearError()
                        viewModel.clearError()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                editorViewModel?.clearError()
                viewModel.clearError()
            }
        } message: {
            Text(editorViewModel?.errorMessage ?? viewModel.errorMessage ?? "Unknown error")
        }

        return AnyView(shell)
    }

    private func titleBinding(for snapshot: NoteSnapshot, mode: NoteDetailMode) -> Binding<String>? {
        guard mode != .read, let editorViewModel, !snapshot.note.isDeleted else {
            return nil
        }

        return Binding(
            get: { editorViewModel.draft?.title ?? snapshot.note.title },
            set: editorViewModel.updateTitle
        )
    }

    private func newLabelBinding() -> Binding<String>? {
        guard viewModel.snapshot?.note.isDeleted != true else {
            return nil
        }

        if viewModel.mode == .read {
            return Binding(
                get: { viewModel.newLabelName },
                set: { viewModel.newLabelName = $0 }
            )
        }

        guard let editorViewModel else {
            return nil
        }

        return Binding(
            get: { editorViewModel.newLabelName },
            set: { editorViewModel.newLabelName = $0 }
        )
    }

    private func prepareEditor() async {
        guard let noteID = viewModel.snapshot?.note.id else {
            editorViewModel = nil
            return
        }

        guard viewModel.mode != .read, viewModel.snapshot?.note.isDeleted != true else {
            if editorViewModel?.noteID != noteID {
                editorViewModel = nil
            }
            return
        }

        if let editorViewModel, editorViewModel.noteID == noteID {
            return
        }

        let nextEditorViewModel = environment.makeNoteEditorViewModel(
            noteID: noteID,
            onSave: {
                await self.viewModel.reloadCurrent()
                await self.onNoteChanged(noteID)
            }
        )
        editorViewModel = nextEditorViewModel
        await nextEditorViewModel.load()
    }
}

private struct NoteDetailShellBody: View {
    let header: AnyView
    let content: AnyView

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) {
            header
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(AppSpacing.large)
    }
}

private struct SnippetPreviewSheet: View {
    let snippet: NoteSnippet
    let syntaxHighlightService: any SyntaxHighlightService
    let onCopy: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var previewLanguage: String

    init(
        snippet: NoteSnippet,
        syntaxHighlightService: any SyntaxHighlightService,
        onCopy: @escaping () -> Void
    ) {
        self.snippet = snippet
        self.syntaxHighlightService = syntaxHighlightService
        self.onCopy = onCopy
        _previewLanguage = State(initialValue: SnippetPresentationBuilder.selectedLanguage(for: snippet))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snippet.title ?? "Snippet")
                        .font(AppTypography.section)
                    Text(SnippetSyntaxLanguage.displayName(for: previewLanguage))
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu("Syntax: \(SnippetSyntaxLanguage.displayName(for: previewLanguage))") {
                    ForEach(SnippetSyntaxLanguage.supportedOptions) { option in
                        Button(option.title) {
                            previewLanguage = option.id
                        }
                    }
                }
                Button("Copy", action: onCopy)
                Button("Done") {
                    dismiss()
                }
            }

            ScrollView {
                SyntaxHighlightedCodeView(
                    code: snippet.code,
                    language: previewLanguage,
                    syntaxHighlightService: syntaxHighlightService,
                    lineLimit: nil
                )
                .padding(AppSpacing.medium)
            }
            .modifier(PanelSurfaceModifier())
        }
        .padding(AppSpacing.large)
        #if os(macOS)
        .frame(minWidth: 680, minHeight: 520)
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }
}

private struct ManualSnippetSheet: View {
    @Binding var draft: ManualSnippetDraft
    let isSaving: Bool
    let isEditing: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text(isEditing ? "Edit Snippet" : "Add Snippet")
                .font(AppTypography.hero)

            TextField("Title", text: $draft.title)
                .textFieldStyle(.roundedBorder)

            TextField("Description", text: $draft.description)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: AppSpacing.small) {
                TextField("Syntax language or auto", text: $draft.language)
                    .textFieldStyle(.roundedBorder)

                Menu("Common Syntax") {
                    ForEach(SnippetSyntaxLanguage.supportedOptions) { option in
                        Button(option.title) {
                            draft.language = option.id
                        }
                    }
                }
            }

            Text("Use `auto` to detect syntax automatically, or choose a common language from the menu.")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $draft.code)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 260)
                .modifier(PanelSurfaceModifier())

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button(isEditing ? "Update" : "Save", action: onSave)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(isSaving || draft.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(AppSpacing.large)
        #if os(macOS)
        .frame(width: 640, height: 520)
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }
}

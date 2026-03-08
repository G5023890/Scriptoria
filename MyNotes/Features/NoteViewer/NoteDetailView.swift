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
        .task(id: viewModel.snapshot?.note.id) {
            await prepareEditor()
        }
    }

    private func detailShell(snapshot: NoteSnapshot) -> some View {
        let isDeleted = snapshot.note.isDeleted
        let effectiveMode: NoteDetailMode = isDeleted ? .read : viewModel.mode
        let headerModeBinding = Binding<NoteDetailMode>(
            get: { isDeleted ? .read : viewModel.mode },
            set: { nextMode in
                guard !isDeleted else { return }
                viewModel.mode = nextMode
            }
        )

        let content = Group {
            if effectiveMode == .read {
                NoteReadView(markdown: snapshot.note.bodyMarkdown)
                NoteMetadataSectionsView(
                    attachmentItems: viewModel.attachmentItems,
                    snippetItems: viewModel.snippetItems,
                    allowsAttachmentRemoval: false,
                    syntaxHighlightService: viewModel.syntaxHighlightService,
                    onPreviewAttachment: viewModel.previewAttachment,
                    onOpenAttachment: viewModel.openAttachment,
                    onRemoveAttachment: { _ in },
                    onCopySnippet: viewModel.copySnippet,
                    onEditSnippet: nil,
                    onRemoveSnippet: nil
                )
            } else if let editorViewModel {
                NoteEditorPane(viewModel: editorViewModel, mode: viewModel.mode)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }

        return VStack(alignment: .leading, spacing: AppSpacing.large) {
            NoteDetailHeaderView(
                snapshot: snapshot,
                mode: headerModeBinding,
                titleBinding: titleBinding(for: snapshot, mode: effectiveMode),
                availableLabels: editorViewModel?.availableLabels ?? [],
                selectedLabels: editorViewModel?.draft?.labels ?? snapshot.labels,
                newLabelName: newLabelBinding(),
                saveStatusText: editorViewModel?.lastSavedText,
                isSaving: editorViewModel?.isSaving ?? false,
                isCreatingLabel: editorViewModel?.isCreatingLabel ?? false,
                onToggleLabel: { label in
                    editorViewModel?.toggleLabel(label)
                },
                onCreateLabel: {
                    Task {
                        await editorViewModel?.createLabel()
                    }
                },
                onAddSnippet: {
                    editorViewModel?.presentManualSnippetSheet()
                },
                onAddAttachment: {
                    editorViewModel?.presentAttachmentImporter()
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
            )
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(AppSpacing.large)
        .fileImporter(
            isPresented: Binding(
                get: { editorViewModel?.isImportingAttachments ?? false },
                set: { newValue in
                    if !newValue {
                        editorViewModel?.isImportingAttachments = false
                    }
                }
            ),
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            guard let editorViewModel else { return }

            switch result {
            case .success(let urls):
                Task {
                    await editorViewModel.importAttachments(from: urls)
                }
            case .failure(let error):
                editorViewModel.errorMessage = "Import failed: \(error.localizedDescription)"
            }
        }
        .sheet(
            item: Binding(
                get: { editorViewModel?.activeAttachmentPreview ?? viewModel.activeAttachmentPreview },
                set: { _ in
                    editorViewModel?.dismissAttachmentPreview()
                    viewModel.dismissAttachmentPreview()
                }
            )
        ) { preview in
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack {
                    Text(preview.title)
                        .font(AppTypography.section)
                    Spacer()
                    Button("Done") {
                        editorViewModel?.dismissAttachmentPreview()
                        viewModel.dismissAttachmentPreview()
                    }
                }

                QuickLookPreviewSheet(url: preview.url)
                    .frame(minWidth: 680, minHeight: 520)
            }
            .padding(AppSpacing.large)
        }
        .sheet(
            isPresented: Binding(
                get: { editorViewModel?.isShowingManualSnippetSheet ?? false },
                set: { newValue in
                    if !newValue {
                        editorViewModel?.isShowingManualSnippetSheet = false
                    }
                }
            )
        ) {
            if let editorViewModel {
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
        guard let editorViewModel, viewModel.snapshot?.note.isDeleted != true else {
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

private struct ManualSnippetSheet: View {
    @Binding var draft: NoteEditorViewModel.ManualSnippetDraft
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
                    .disabled(isSaving || draft.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(AppSpacing.large)
        .frame(width: 640, height: 520)
    }
}

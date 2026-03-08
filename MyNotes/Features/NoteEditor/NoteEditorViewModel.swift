import Observation
import SwiftUI

@MainActor
@Observable
final class NoteEditorViewModel {
    struct ManualSnippetDraft {
        var snippetID: String?
        var title = ""
        var description = ""
        var language = SnippetSyntaxLanguage.auto
        var code = ""
    }

    var draft: NoteDraft?
    var attachmentItems: [AttachmentItem] = []
    var snippetItems: [SnippetItem] = []
    var availableLabels: [Label] = []
    var newLabelName = ""
    var isSaving = false
    var isCreatingLabel = false
    var isImportingAttachments = false
    var isShowingManualSnippetSheet = false
    var isSavingManualSnippet = false
    var isEditingManualSnippet = false
    var manualSnippetDraft = ManualSnippetDraft()
    var lastSavedText = "Not saved yet"
    var activeAttachmentPreview: AttachmentPreviewState?
    var errorMessage: String?

    let noteID: NoteID
    private let loadNoteDraftUseCase: LoadNoteDraftUseCase
    private let listLabelsUseCase: ListLabelsUseCase
    private let createLabelUseCase: CreateLabelUseCase
    private let updateNoteUseCase: UpdateNoteUseCase
    private let createManualSnippetUseCase: CreateManualSnippetUseCase
    private let updateManualSnippetUseCase: UpdateManualSnippetUseCase
    private let removeSnippetUseCase: RemoveSnippetUseCase
    private let importAttachmentUseCase: ImportAttachmentUseCase
    private let removeAttachmentUseCase: RemoveAttachmentUseCase
    private let prepareAttachmentPreviewUseCase: PrepareAttachmentPreviewUseCase
    private let openAttachmentUseCase: OpenAttachmentUseCase
    private let copySnippetUseCase: CopySnippetUseCase
    private let fileService: any FileService
    let syntaxHighlightService: any SyntaxHighlightService
    private let onSave: @MainActor () async -> Void
    private var autosaveTask: Task<Void, Never>?

    init(
        noteID: NoteID,
        loadNoteDraftUseCase: LoadNoteDraftUseCase,
        listLabelsUseCase: ListLabelsUseCase,
        createLabelUseCase: CreateLabelUseCase,
        updateNoteUseCase: UpdateNoteUseCase,
        createManualSnippetUseCase: CreateManualSnippetUseCase,
        updateManualSnippetUseCase: UpdateManualSnippetUseCase,
        removeSnippetUseCase: RemoveSnippetUseCase,
        importAttachmentUseCase: ImportAttachmentUseCase,
        removeAttachmentUseCase: RemoveAttachmentUseCase,
        prepareAttachmentPreviewUseCase: PrepareAttachmentPreviewUseCase,
        openAttachmentUseCase: OpenAttachmentUseCase,
        copySnippetUseCase: CopySnippetUseCase,
        fileService: any FileService,
        syntaxHighlightService: any SyntaxHighlightService,
        onSave: @escaping @MainActor () async -> Void
    ) {
        self.noteID = noteID
        self.loadNoteDraftUseCase = loadNoteDraftUseCase
        self.listLabelsUseCase = listLabelsUseCase
        self.createLabelUseCase = createLabelUseCase
        self.updateNoteUseCase = updateNoteUseCase
        self.createManualSnippetUseCase = createManualSnippetUseCase
        self.updateManualSnippetUseCase = updateManualSnippetUseCase
        self.removeSnippetUseCase = removeSnippetUseCase
        self.importAttachmentUseCase = importAttachmentUseCase
        self.removeAttachmentUseCase = removeAttachmentUseCase
        self.prepareAttachmentPreviewUseCase = prepareAttachmentPreviewUseCase
        self.openAttachmentUseCase = openAttachmentUseCase
        self.copySnippetUseCase = copySnippetUseCase
        self.fileService = fileService
        self.syntaxHighlightService = syntaxHighlightService
        self.onSave = onSave
    }

    func load() async {
        do {
            draft = try await loadNoteDraftUseCase.execute(noteID: noteID)
            availableLabels = try await listLabelsUseCase.execute()
            rebuildPresentationState()
            lastSavedText = "Loaded"
        } catch {
            draft = nil
            attachmentItems = []
            snippetItems = []
            availableLabels = []
        }
    }

    func updateTitle(_ title: String) {
        guard var draft else { return }
        draft.title = title
        draft.hasChanges = true
        self.draft = draft
        scheduleAutosave()
    }

    func updateBody(_ body: String) {
        guard var draft else { return }
        draft.bodyMarkdown = body
        draft.hasChanges = true
        self.draft = draft
        scheduleAutosave()
    }

    func toggleLabel(_ label: Label) {
        guard var draft else { return }
        if draft.labels.contains(label) {
            draft.labels.removeAll { $0.id == label.id }
        } else {
            draft.labels.append(label)
        }
        draft.hasChanges = true
        self.draft = draft
        scheduleAutosave()
    }

    func createLabel() async {
        let candidateName = newLabelName
        guard !candidateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isCreatingLabel = true
        defer { isCreatingLabel = false }

        do {
            guard let label = try await createLabelUseCase.execute(name: candidateName) else { return }
            newLabelName = ""
            availableLabels = try await listLabelsUseCase.execute()

            guard var draft else { return }
            if !draft.labels.contains(where: { $0.id == label.id }) {
                draft.labels.append(label)
                draft.labels.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                draft.hasChanges = true
                self.draft = draft
                scheduleAutosave()
            }
        } catch {
            errorMessage = "Label creation failed: \(error.localizedDescription)"
        }
    }

    func saveNow() async {
        guard let draft, draft.hasChanges else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            if let updated = try await updateNoteUseCase.execute(draft: draft) {
                if var refreshedDraft = self.draft {
                    refreshedDraft.title = updated.title
                    refreshedDraft.bodyMarkdown = updated.bodyMarkdown
                    refreshedDraft.hasChanges = false
                    self.draft = refreshedDraft
                }
                rebuildPresentationState()
            }
            lastSavedText = "Saved \(Date().formatted(date: .omitted, time: .shortened))"
            await onSave()
        } catch {
            lastSavedText = "Save failed"
            errorMessage = error.localizedDescription
        }
    }

    func presentAttachmentImporter() {
        isImportingAttachments = true
    }

    func presentManualSnippetSheet() {
        manualSnippetDraft = ManualSnippetDraft()
        isEditingManualSnippet = false
        isShowingManualSnippetSheet = true
    }

    func presentEditSnippetSheet(_ snippet: NoteSnippet) {
        manualSnippetDraft = ManualSnippetDraft(
            snippetID: snippet.id,
            title: snippet.title ?? "",
            description: snippet.snippetDescription ?? "",
            language: SnippetPresentationBuilder.selectedLanguage(for: snippet),
            code: snippet.code
        )
        isEditingManualSnippet = true
        isShowingManualSnippetSheet = true
    }

    func createManualSnippet() async {
        guard let draft else { return }
        let isEditing = manualSnippetDraft.snippetID != nil
        isSavingManualSnippet = true
        defer { isSavingManualSnippet = false }

        do {
            var nextDraft = draft
            if let snippetID = manualSnippetDraft.snippetID {
                guard let snippet = try await updateManualSnippetUseCase.execute(
                    snippetID: snippetID,
                    noteID: noteID,
                    title: manualSnippetDraft.title,
                    description: manualSnippetDraft.description,
                    language: manualSnippetDraft.language,
                    code: manualSnippetDraft.code
                ) else {
                    return
                }

                guard let index = nextDraft.snippets.firstIndex(where: { $0.id == snippet.id }) else {
                    return
                }
                nextDraft.snippets[index] = snippet
            } else {
                guard let snippet = try await createManualSnippetUseCase.execute(
                    noteID: noteID,
                    title: manualSnippetDraft.title,
                    description: manualSnippetDraft.description,
                    language: manualSnippetDraft.language,
                    code: manualSnippetDraft.code
                ) else {
                    return
                }
                nextDraft.snippets.append(snippet)
            }

            nextDraft.snippets.sort { $0.updatedAt > $1.updatedAt }
            self.draft = nextDraft
            rebuildPresentationState()
            isShowingManualSnippetSheet = false
            isEditingManualSnippet = false
            manualSnippetDraft = ManualSnippetDraft()
            lastSavedText = isEditing ? "Updated snippet" : "Saved snippet"
            await onSave()
        } catch {
            errorMessage = isEditing
                ? "Snippet update failed: \(error.localizedDescription)"
                : "Snippet creation failed: \(error.localizedDescription)"
        }
    }

    func removeSnippet(_ snippet: NoteSnippet) async {
        guard var draft else { return }

        do {
            try await removeSnippetUseCase.execute(snippetID: snippet.id, noteID: noteID)
            draft.snippets.removeAll { $0.id == snippet.id }
            self.draft = draft
            rebuildPresentationState()
            lastSavedText = "Removed snippet"
            await onSave()
        } catch {
            errorMessage = "Snippet remove failed: \(error.localizedDescription)"
        }
    }

    func importAttachments(from urls: [URL]) async {
        guard !urls.isEmpty, var draft else { return }

        do {
            let importedAttachments = try await importAttachmentUseCase.execute(sourceURLs: urls, noteID: noteID)
            draft.attachments = (importedAttachments + draft.attachments)
                .sorted { $0.createdAt > $1.createdAt }
            self.draft = draft
            rebuildPresentationState()
            lastSavedText = importedAttachments.count == 1
                ? "Imported \(importedAttachments[0].originalFileName)"
                : "Imported \(importedAttachments.count) attachments"
            await onSave()
        } catch {
            errorMessage = "Import failed: \(error.localizedDescription)"
            lastSavedText = "Import failed"
        }
    }

    func removeAttachment(_ attachment: Attachment) async {
        guard var draft else { return }

        do {
            try await removeAttachmentUseCase.execute(attachment: attachment)
            draft.attachments.removeAll { $0.id == attachment.id }
            self.draft = draft
            rebuildPresentationState()
            lastSavedText = "Removed \(attachment.originalFileName)"
            await onSave()
        } catch {
            errorMessage = "Remove failed: \(error.localizedDescription)"
            lastSavedText = "Remove failed"
        }
    }

    func previewAttachment(_ attachment: Attachment) {
        do {
            guard let previewURL = try prepareAttachmentPreviewUseCase.execute(for: attachment) else { return }
            activeAttachmentPreview = AttachmentPreviewState(
                id: attachment.id,
                title: attachment.originalFileName,
                url: previewURL
            )
        } catch {
            errorMessage = "Preview failed: \(error.localizedDescription)"
        }
    }

    func openAttachment(_ attachment: Attachment) {
        do {
            try openAttachmentUseCase.execute(for: attachment)
        } catch {
            errorMessage = "Open failed: \(error.localizedDescription)"
        }
    }

    func dismissAttachmentPreview() {
        activeAttachmentPreview = nil
    }

    func copySnippet(_ snippet: NoteSnippet) {
        copySnippetUseCase.execute(snippet: snippet)
        lastSavedText = "Copied \(SnippetSyntaxLanguage.displayName(for: SnippetPresentationBuilder.selectedLanguage(for: snippet))) snippet"
    }

    func clearError() {
        errorMessage = nil
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await self?.saveNow()
        }
    }

    private func rebuildPresentationState() {
        guard let draft else {
            attachmentItems = []
            snippetItems = []
            return
        }

        attachmentItems = draft.attachments.map { attachment in
            let previewURL = try? prepareAttachmentPreviewUseCase.execute(for: attachment)
            let codePreview = attachment.category == .code
                ? (try? fileService.readTextFile(atRelativePath: attachment.relativePath, maxCharacters: 2_500))
                : nil
            let codeLanguage = attachment.category == .code
                ? SnippetSyntaxLanguage.detectAttachmentLanguage(
                    fileName: attachment.originalFileName,
                    mimeType: attachment.mimeType
                )
                : nil

            return AttachmentPresentationBuilder.make(
                attachment: attachment,
                previewURL: previewURL ?? nil,
                codePreview: codePreview,
                codeLanguage: codeLanguage
            )
        }
        snippetItems = draft.snippets.map { snippet in
            SnippetPresentationBuilder.make(snippet: snippet, syntaxHighlightService: syntaxHighlightService)
        }
    }
}

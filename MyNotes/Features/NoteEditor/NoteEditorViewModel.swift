import Observation
import SwiftUI

@MainActor
@Observable
final class NoteEditorViewModel {
    var draft: NoteDraft?
    var toDoItems: [NoteToDoItem] = []
    var deletedToDoItems: [NoteToDoItem] = []
    var activeToDoDraft: ToDoDraft?
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
    var activeAttachmentEditDraft: AttachmentEditDraft?
    var isSavingAttachment = false
    var errorMessage: String?

    let noteID: NoteID
    private let loadNoteDraftUseCase: LoadNoteDraftUseCase
    private let listLabelsUseCase: ListLabelsUseCase
    private let createLabelUseCase: CreateLabelUseCase
    private let updateNoteUseCase: UpdateNoteUseCase
    private let createToDoUseCase: CreateToDoUseCase
    private let updateToDoUseCase: UpdateToDoUseCase
    private let deleteToDoUseCase: DeleteToDoUseCase
    private let removeToDoUseCase: RemoveToDoUseCase
    private let restoreToDoUseCase: RestoreToDoUseCase
    private let completeToDoUseCase: CompleteToDoUseCase
    private let reorderToDosUseCase: ReorderToDosUseCase
    private let listToDosForNoteUseCase: ListToDosForNoteUseCase
    private let createManualSnippetUseCase: CreateManualSnippetUseCase
    private let updateManualSnippetUseCase: UpdateManualSnippetUseCase
    private let archiveSnippetUseCase: ArchiveSnippetUseCase
    private let removeSnippetUseCase: RemoveSnippetUseCase
    private let importAttachmentUseCase: ImportAttachmentUseCase
    private let updateAttachmentUseCase: UpdateAttachmentUseCase
    private let archiveAttachmentUseCase: ArchiveAttachmentUseCase
    private let removeAttachmentUseCase: RemoveAttachmentUseCase
    private let prepareAttachmentPreviewUseCase: PrepareAttachmentPreviewUseCase
    private let openAttachmentUseCase: OpenAttachmentUseCase
    private let copySnippetUseCase: CopySnippetUseCase
    let syntaxHighlightService: any SyntaxHighlightService
    private let onSave: @MainActor () async -> Void
    private var autosaveTask: Task<Void, Never>?

    init(
        noteID: NoteID,
        loadNoteDraftUseCase: LoadNoteDraftUseCase,
        listLabelsUseCase: ListLabelsUseCase,
        createLabelUseCase: CreateLabelUseCase,
        updateNoteUseCase: UpdateNoteUseCase,
        createToDoUseCase: CreateToDoUseCase,
        updateToDoUseCase: UpdateToDoUseCase,
        deleteToDoUseCase: DeleteToDoUseCase,
        removeToDoUseCase: RemoveToDoUseCase,
        restoreToDoUseCase: RestoreToDoUseCase,
        completeToDoUseCase: CompleteToDoUseCase,
        reorderToDosUseCase: ReorderToDosUseCase,
        listToDosForNoteUseCase: ListToDosForNoteUseCase,
        createManualSnippetUseCase: CreateManualSnippetUseCase,
        updateManualSnippetUseCase: UpdateManualSnippetUseCase,
        archiveSnippetUseCase: ArchiveSnippetUseCase,
        removeSnippetUseCase: RemoveSnippetUseCase,
        importAttachmentUseCase: ImportAttachmentUseCase,
        updateAttachmentUseCase: UpdateAttachmentUseCase,
        archiveAttachmentUseCase: ArchiveAttachmentUseCase,
        removeAttachmentUseCase: RemoveAttachmentUseCase,
        prepareAttachmentPreviewUseCase: PrepareAttachmentPreviewUseCase,
        openAttachmentUseCase: OpenAttachmentUseCase,
        copySnippetUseCase: CopySnippetUseCase,
        syntaxHighlightService: any SyntaxHighlightService,
        onSave: @escaping @MainActor () async -> Void
    ) {
        self.noteID = noteID
        self.loadNoteDraftUseCase = loadNoteDraftUseCase
        self.listLabelsUseCase = listLabelsUseCase
        self.createLabelUseCase = createLabelUseCase
        self.updateNoteUseCase = updateNoteUseCase
        self.createToDoUseCase = createToDoUseCase
        self.updateToDoUseCase = updateToDoUseCase
        self.deleteToDoUseCase = deleteToDoUseCase
        self.removeToDoUseCase = removeToDoUseCase
        self.restoreToDoUseCase = restoreToDoUseCase
        self.completeToDoUseCase = completeToDoUseCase
        self.reorderToDosUseCase = reorderToDosUseCase
        self.listToDosForNoteUseCase = listToDosForNoteUseCase
        self.createManualSnippetUseCase = createManualSnippetUseCase
        self.updateManualSnippetUseCase = updateManualSnippetUseCase
        self.archiveSnippetUseCase = archiveSnippetUseCase
        self.removeSnippetUseCase = removeSnippetUseCase
        self.importAttachmentUseCase = importAttachmentUseCase
        self.updateAttachmentUseCase = updateAttachmentUseCase
        self.archiveAttachmentUseCase = archiveAttachmentUseCase
        self.removeAttachmentUseCase = removeAttachmentUseCase
        self.prepareAttachmentPreviewUseCase = prepareAttachmentPreviewUseCase
        self.openAttachmentUseCase = openAttachmentUseCase
        self.copySnippetUseCase = copySnippetUseCase
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
            toDoItems = []
            deletedToDoItems = []
            attachmentItems = []
            snippetItems = []
            availableLabels = []
            activeAttachmentEditDraft = nil
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

                if let index = nextDraft.snippets.firstIndex(where: { $0.id == snippet.id }) {
                    nextDraft.snippets[index] = snippet
                } else {
                    nextDraft.snippets.append(snippet)
                }
            }

            nextDraft.snippets.sort(by: Self.snippetSort)
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

    func archiveSnippet(_ snippet: NoteSnippet) async {
        guard var draft else { return }

        do {
            guard let archivedSnippet = try await archiveSnippetUseCase.execute(snippetID: snippet.id) else {
                return
            }

            guard let index = draft.snippets.firstIndex(where: { $0.id == archivedSnippet.id }) else {
                return
            }

            draft.snippets[index] = archivedSnippet
            draft.snippets.sort(by: Self.snippetSort)
            self.draft = draft
            rebuildPresentationState()
            lastSavedText = "Archived snippet"
            await onSave()
        } catch {
            errorMessage = "Snippet archive failed: \(error.localizedDescription)"
            lastSavedText = "Archive failed"
        }
    }

    func createToDo(draft taskDraft: ToDoDraft) async {
        do {
            guard let todo = try await createToDoUseCase.execute(draft: taskDraft) else { return }
            try await refreshToDos()
            lastSavedText = "Added \(todo.title)"
            await onSave()
        } catch {
            errorMessage = "Task creation failed: \(error.localizedDescription)"
        }
    }

    func updateToDo(draft taskDraft: ToDoDraft) async {
        do {
            guard let todo = try await updateToDoUseCase.execute(draft: taskDraft) else { return }
            try await refreshToDos()
            lastSavedText = "Updated \(todo.title)"
            await onSave()
        } catch {
            errorMessage = "Task update failed: \(error.localizedDescription)"
        }
    }

    func toggleToDoCompletion(_ todo: ToDo) async {
        do {
            try await completeToDoUseCase.execute(toDoID: todo.id, isCompleted: !todo.isCompleted)
            try await refreshToDos()
            lastSavedText = todo.isCompleted ? "Marked incomplete" : "Completed \(todo.title)"
            await onSave()
        } catch {
            errorMessage = "Task update failed: \(error.localizedDescription)"
        }
    }

    func deleteToDo(_ todo: ToDo) async {
        do {
            try await removeToDoUseCase.execute(toDoID: todo.id)
            try await refreshToDos()
            lastSavedText = "Removed \(todo.title)"
            await onSave()
        } catch {
            errorMessage = "Task remove failed: \(error.localizedDescription)"
        }
    }

    func restoreToDo(_ todo: ToDo) async {
        do {
            try await restoreToDoUseCase.execute(toDoID: todo.id)
            try await refreshToDos()
            lastSavedText = "Restored \(todo.title)"
            await onSave()
        } catch {
            errorMessage = "Task restore failed: \(error.localizedDescription)"
        }
    }

    func removeToDo(_ todo: ToDo) async {
        do {
            try await removeToDoUseCase.execute(toDoID: todo.id)
            try await refreshToDos()
            lastSavedText = "Removed \(todo.title)"
            await onSave()
        } catch {
            errorMessage = "Task remove failed: \(error.localizedDescription)"
        }
    }

    func moveToDo(_ todo: ToDo, direction: NoteTaskMoveDirection) async {
        guard draft != nil else { return }

        var orderedIDs = toDoItems.map(\.id)
        guard let index = orderedIDs.firstIndex(of: todo.id) else { return }
        let destination = direction == .up ? index - 1 : index + 1
        guard orderedIDs.indices.contains(destination) else { return }

        orderedIDs.swapAt(index, destination)

        do {
            try await reorderToDosUseCase.execute(noteID: noteID, orderedToDoIDs: orderedIDs)
            try await refreshToDos()
            lastSavedText = "Reordered tasks"
            await onSave()
        } catch {
            errorMessage = "Task reorder failed: \(error.localizedDescription)"
        }
    }

    func importAttachments(from urls: [URL]) async {
        guard !urls.isEmpty, var draft else { return }

        do {
            let importedAttachments = try await importAttachmentUseCase.execute(sourceURLs: urls, noteID: noteID)
            draft.attachments = (importedAttachments + draft.attachments)
                .sorted(by: Self.attachmentSort)
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

    func presentEditAttachmentSheet(_ attachment: Attachment) {
        activeAttachmentEditDraft = AttachmentEditDraft(attachment: attachment)
    }

    func dismissAttachmentSheet() {
        activeAttachmentEditDraft = nil
    }

    func updateAttachment(draft: AttachmentEditDraft) async {
        guard var currentDraft = self.draft else { return }
        isSavingAttachment = true
        defer { isSavingAttachment = false }

        do {
            guard let updatedAttachment = try await updateAttachmentUseCase.execute(
                attachment: draft.attachment,
                description: draft.description
            ) else {
                errorMessage = "Attachment update failed: attachment not found"
                return
            }

            guard let index = currentDraft.attachments.firstIndex(where: { $0.id == updatedAttachment.id }) else {
                return
            }

            currentDraft.attachments[index] = updatedAttachment
            currentDraft.attachments.sort(by: Self.attachmentSort)
            self.draft = currentDraft
            rebuildPresentationState()
            activeAttachmentEditDraft = nil
            lastSavedText = "Updated attachment"
            await onSave()
        } catch {
            errorMessage = "Attachment update failed: \(error.localizedDescription)"
        }
    }

    func archiveAttachment(_ attachment: Attachment) async {
        guard var draft else { return }

        do {
            guard let archivedAttachment = try await archiveAttachmentUseCase.execute(attachmentID: attachment.id) else {
                return
            }

            guard let index = draft.attachments.firstIndex(where: { $0.id == archivedAttachment.id }) else {
                return
            }

            draft.attachments[index] = archivedAttachment
            draft.attachments.sort(by: Self.attachmentSort)
            self.draft = draft
            rebuildPresentationState()
            lastSavedText = "Archived \(attachment.originalFileName)"
            await onSave()
        } catch {
            errorMessage = "Archive failed: \(error.localizedDescription)"
            lastSavedText = "Archive failed"
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

    func presentNewToDoSheet() {
        activeToDoDraft = ToDoDraft(noteID: noteID)
    }

    func presentEditToDoSheet(_ todo: ToDo) {
        activeToDoDraft = ToDoDraft(todo: todo)
    }

    func dismissToDoSheet() {
        activeToDoDraft = nil
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
            toDoItems = []
            deletedToDoItems = []
            attachmentItems = []
            snippetItems = []
            activeAttachmentEditDraft = nil
            return
        }

        let todoPresentation = ToDoPresentationBuilder.makeNoteItems(from: draft.todos.sorted(by: ToDoSorting.note))
        toDoItems = todoPresentation.active
        deletedToDoItems = todoPresentation.deleted
        attachmentItems = draft.attachments.sorted(by: Self.attachmentSort).map { attachment in
            AttachmentPresentationBuilder.make(attachment: attachment, previewURL: nil)
        }
        snippetItems = draft.snippets.sorted(by: Self.snippetSort).map { snippet in
            SnippetPresentationBuilder.make(snippet: snippet)
        }
    }

    private func refreshToDos() async throws {
        guard var draft else { return }
        draft.todos = try await listToDosForNoteUseCase.execute(noteID: noteID)
        self.draft = draft
        rebuildPresentationState()
    }

    private static func attachmentSort(_ lhs: Attachment, _ rhs: Attachment) -> Bool {
        if lhs.isArchived != rhs.isArchived {
            return !lhs.isArchived && rhs.isArchived
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }
        return lhs.id.rawValue < rhs.id.rawValue
    }

    private static func snippetSort(_ lhs: NoteSnippet, _ rhs: NoteSnippet) -> Bool {
        if lhs.isArchived != rhs.isArchived {
            return !lhs.isArchived && rhs.isArchived
        }
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        return lhs.id < rhs.id
    }
}

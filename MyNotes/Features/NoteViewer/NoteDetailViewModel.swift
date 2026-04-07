import Foundation
import Observation

@MainActor
@Observable
final class NoteDetailViewModel {
    var snapshot: NoteSnapshot?
    var attachmentItems: [AttachmentItem] = []
    var snippetItems: [SnippetItem] = []
    var toDoItems: [NoteToDoItem] = []
    var deletedToDoItems: [NoteToDoItem] = []
    var availableLabels: [Label] = []
    var newLabelName = ""
    var isCreatingLabel = false
    var activeToDoDraft: ToDoDraft?
    var isImportingAttachments = false
    var isShowingManualSnippetSheet = false
    var isSavingManualSnippet = false
    var manualSnippetDraft = ManualSnippetDraft()
    var mode: NoteDetailMode = .read
    var isLoading = false
    var activeAttachmentPreview: AttachmentPreviewState?
    var activeAttachmentEditDraft: AttachmentEditDraft?
    var isSavingAttachment = false
    var activeSnippetPreview: NoteSnippet?
    var errorMessage: String?

    private let getNoteSnapshotUseCase: GetNoteSnapshotUseCase
    private let listLabelsUseCase: ListLabelsUseCase
    private let createLabelUseCase: CreateLabelUseCase
    private let assignLabelsUseCase: AssignLabelsUseCase
    private let deleteNoteUseCase: DeleteNoteUseCase
    private let restoreNoteUseCase: RestoreNoteUseCase
    private let togglePinUseCase: TogglePinUseCase
    private let toggleFavoriteUseCase: ToggleFavoriteUseCase
    private let createToDoUseCase: CreateToDoUseCase
    private let updateToDoUseCase: UpdateToDoUseCase
    private let deleteToDoUseCase: DeleteToDoUseCase
    private let removeToDoUseCase: RemoveToDoUseCase
    private let restoreToDoUseCase: RestoreToDoUseCase
    private let completeToDoUseCase: CompleteToDoUseCase
    private let reorderToDosUseCase: ReorderToDosUseCase
    private let importAttachmentUseCase: ImportAttachmentUseCase
    private let updateAttachmentUseCase: UpdateAttachmentUseCase
    private let createManualSnippetUseCase: CreateManualSnippetUseCase
    private let removeAttachmentUseCase: RemoveAttachmentUseCase
    private let prepareAttachmentPreviewUseCase: PrepareAttachmentPreviewUseCase
    private let openAttachmentUseCase: OpenAttachmentUseCase
    private let copySnippetUseCase: CopySnippetUseCase
    private let attachmentsRepository: any AttachmentsRepository
    let syntaxHighlightService: any SyntaxHighlightService

    init(
        getNoteSnapshotUseCase: GetNoteSnapshotUseCase,
        listLabelsUseCase: ListLabelsUseCase,
        createLabelUseCase: CreateLabelUseCase,
        assignLabelsUseCase: AssignLabelsUseCase,
        deleteNoteUseCase: DeleteNoteUseCase,
        restoreNoteUseCase: RestoreNoteUseCase,
        togglePinUseCase: TogglePinUseCase,
        toggleFavoriteUseCase: ToggleFavoriteUseCase,
        createToDoUseCase: CreateToDoUseCase,
        updateToDoUseCase: UpdateToDoUseCase,
        deleteToDoUseCase: DeleteToDoUseCase,
        removeToDoUseCase: RemoveToDoUseCase,
        restoreToDoUseCase: RestoreToDoUseCase,
        completeToDoUseCase: CompleteToDoUseCase,
        reorderToDosUseCase: ReorderToDosUseCase,
        importAttachmentUseCase: ImportAttachmentUseCase,
        updateAttachmentUseCase: UpdateAttachmentUseCase,
        createManualSnippetUseCase: CreateManualSnippetUseCase,
        removeAttachmentUseCase: RemoveAttachmentUseCase,
        prepareAttachmentPreviewUseCase: PrepareAttachmentPreviewUseCase,
        openAttachmentUseCase: OpenAttachmentUseCase,
        copySnippetUseCase: CopySnippetUseCase,
        attachmentsRepository: any AttachmentsRepository,
        syntaxHighlightService: any SyntaxHighlightService
    ) {
        self.getNoteSnapshotUseCase = getNoteSnapshotUseCase
        self.listLabelsUseCase = listLabelsUseCase
        self.createLabelUseCase = createLabelUseCase
        self.assignLabelsUseCase = assignLabelsUseCase
        self.deleteNoteUseCase = deleteNoteUseCase
        self.restoreNoteUseCase = restoreNoteUseCase
        self.togglePinUseCase = togglePinUseCase
        self.toggleFavoriteUseCase = toggleFavoriteUseCase
        self.createToDoUseCase = createToDoUseCase
        self.updateToDoUseCase = updateToDoUseCase
        self.deleteToDoUseCase = deleteToDoUseCase
        self.removeToDoUseCase = removeToDoUseCase
        self.restoreToDoUseCase = restoreToDoUseCase
        self.completeToDoUseCase = completeToDoUseCase
        self.reorderToDosUseCase = reorderToDosUseCase
        self.importAttachmentUseCase = importAttachmentUseCase
        self.updateAttachmentUseCase = updateAttachmentUseCase
        self.createManualSnippetUseCase = createManualSnippetUseCase
        self.removeAttachmentUseCase = removeAttachmentUseCase
        self.prepareAttachmentPreviewUseCase = prepareAttachmentPreviewUseCase
        self.openAttachmentUseCase = openAttachmentUseCase
        self.copySnippetUseCase = copySnippetUseCase
        self.attachmentsRepository = attachmentsRepository
        self.syntaxHighlightService = syntaxHighlightService
    }

    func load(noteID: NoteID?, preserveMode: Bool = false) async {
        guard let noteID else {
            snapshot = nil
            mode = .read
            availableLabels = []
            newLabelName = ""
            isCreatingLabel = false
            toDoItems = []
            deletedToDoItems = []
            attachmentItems = []
            snippetItems = []
            activeAttachmentEditDraft = nil
            return
        }

        let isReloadingSameNote = preserveMode && snapshot?.note.id == noteID
        let preservedMode = mode

        isLoading = true
        defer { isLoading = false }
        if !isReloadingSameNote {
            mode = .read
        }

        do {
            let nextSnapshot = try await makeSnapshot(noteID: noteID)
            availableLabels = try await listLabelsUseCase.execute()
            let nextMode: NoteDetailMode = isReloadingSameNote ? preservedMode : .read
            mode = nextMode
            snapshot = nextSnapshot
            rebuildPresentationState()
        } catch {
            snapshot = nil
            mode = .read
            availableLabels = []
            newLabelName = ""
            isCreatingLabel = false
            toDoItems = []
            deletedToDoItems = []
            attachmentItems = []
            snippetItems = []
            activeAttachmentEditDraft = nil
        }
    }

    func reloadCurrent() async {
        await load(noteID: snapshot?.note.id, preserveMode: true)
    }

    func togglePin() async {
        guard let snapshot else { return }
        try? await togglePinUseCase.execute(noteID: snapshot.note.id, isPinned: !snapshot.note.isPinned)
        await reloadCurrent()
    }

    func toggleFavorite() async {
        guard let snapshot else { return }
        try? await toggleFavoriteUseCase.execute(noteID: snapshot.note.id, isFavorite: !snapshot.note.isFavorite)
        await reloadCurrent()
    }

    func deleteCurrentNote() async {
        guard let snapshot else { return }

        do {
            try await deleteNoteUseCase.execute(noteID: snapshot.note.id)
            await reloadCurrent()
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
        }
    }

    func restoreCurrentNote() async {
        guard let snapshot else { return }

        do {
            try await restoreNoteUseCase.execute(noteID: snapshot.note.id)
            await reloadCurrent()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
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

    func removeAttachment(_ attachment: Attachment) async {
        do {
            try await removeAttachmentUseCase.execute(attachment: attachment)
            await reloadCurrent()
        } catch {
            errorMessage = "Remove failed: \(error.localizedDescription)"
        }
    }

    func presentEditAttachmentSheet(_ attachment: Attachment) {
        activeAttachmentEditDraft = AttachmentEditDraft(attachment: attachment)
    }

    func dismissAttachmentSheet() {
        activeAttachmentEditDraft = nil
    }

    func updateAttachment(draft: AttachmentEditDraft) async {
        isSavingAttachment = true
        defer { isSavingAttachment = false }

        do {
            guard let _ = try await updateAttachmentUseCase.execute(
                attachment: draft.attachment,
                description: draft.description
            ) else {
                errorMessage = "Attachment update failed: attachment not found"
                return
            }

            activeAttachmentEditDraft = nil
            await reloadCurrent()
        } catch {
            errorMessage = "Attachment update failed: \(error.localizedDescription)"
        }
    }

    func copySnippet(_ snippet: NoteSnippet) {
        Task {
            let resolvedSnippet = await resolveSnippet(snippet)
            guard let resolvedSnippet else { return }
            copySnippetUseCase.execute(snippet: resolvedSnippet)
        }
    }

    func previewSnippet(_ snippet: NoteSnippet) {
        Task {
            activeSnippetPreview = await resolveSnippet(snippet)
        }
    }

    func dismissAttachmentPreview() {
        activeAttachmentPreview = nil
    }

    func dismissSnippetPreview() {
        activeSnippetPreview = nil
    }

    func clearError() {
        errorMessage = nil
    }

    func toggleLabel(_ label: Label) async {
        guard let snapshot else { return }

        let hasLabel = snapshot.labels.contains(where: { $0.id == label.id })
        var labelIDs = snapshot.labels.map(\.id)

        if hasLabel {
            labelIDs.removeAll { $0 == label.id }
        } else {
            labelIDs.append(label.id)
        }

        do {
            try await assignLabelsUseCase.execute(noteID: snapshot.note.id, labelIDs: labelIDs)
            await reloadCurrent()
        } catch {
            errorMessage = "Label update failed: \(error.localizedDescription)"
        }
    }

    func createLabel() async {
        guard let snapshot else { return }

        let candidateName = newLabelName
        guard !candidateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isCreatingLabel = true
        defer { isCreatingLabel = false }

        do {
            guard let label = try await createLabelUseCase.execute(name: candidateName) else { return }
            newLabelName = ""

            var labelIDs = snapshot.labels.map(\.id)
            if !labelIDs.contains(label.id) {
                labelIDs.append(label.id)
            }

            try await assignLabelsUseCase.execute(noteID: snapshot.note.id, labelIDs: labelIDs)
            await reloadCurrent()
        } catch {
            errorMessage = "Label creation failed: \(error.localizedDescription)"
        }
    }

    func presentNewToDoSheet() {
        guard let noteID = snapshot?.note.id else { return }
        activeToDoDraft = ToDoDraft(noteID: noteID)
    }

    func presentEditToDoSheet(_ todo: ToDo) {
        activeToDoDraft = ToDoDraft(todo: todo)
    }

    func dismissToDoSheet() {
        activeToDoDraft = nil
    }

    func presentAttachmentImporter() {
        isImportingAttachments = true
    }

    func presentManualSnippetSheet() {
        manualSnippetDraft = ManualSnippetDraft()
        isShowingManualSnippetSheet = true
    }

    func createManualSnippet() async -> Bool {
        guard let noteID = snapshot?.note.id else { return false }

        isSavingManualSnippet = true
        defer { isSavingManualSnippet = false }

        do {
            guard try await createManualSnippetUseCase.execute(
                noteID: noteID,
                title: manualSnippetDraft.title,
                description: manualSnippetDraft.description,
                language: manualSnippetDraft.language,
                code: manualSnippetDraft.code
            ) != nil else {
                return false
            }

            isShowingManualSnippetSheet = false
            manualSnippetDraft = ManualSnippetDraft()
            await reloadCurrent()
            return true
        } catch {
            errorMessage = "Snippet creation failed: \(error.localizedDescription)"
            return false
        }
    }

    func importAttachments(from urls: [URL]) async -> Bool {
        guard let noteID = snapshot?.note.id, !urls.isEmpty else { return false }
        defer { isImportingAttachments = false }

        do {
            _ = try await importAttachmentUseCase.execute(sourceURLs: urls, noteID: noteID)
            await reloadCurrent()
            return true
        } catch {
            errorMessage = "Import failed: \(error.localizedDescription)"
            return false
        }
    }

    func createToDo(draft: ToDoDraft) async {
        do {
            _ = try await createToDoUseCase.execute(draft: draft)
            await reloadCurrent()
        } catch {
            errorMessage = "Task creation failed: \(error.localizedDescription)"
        }
    }

    func updateToDo(draft: ToDoDraft) async {
        do {
            _ = try await updateToDoUseCase.execute(draft: draft)
            await reloadCurrent()
        } catch {
            errorMessage = "Task update failed: \(error.localizedDescription)"
        }
    }

    func toggleToDoCompletion(_ todo: ToDo) async {
        do {
            try await completeToDoUseCase.execute(toDoID: todo.id, isCompleted: !todo.isCompleted)
            await reloadCurrent()
        } catch {
            errorMessage = "Task update failed: \(error.localizedDescription)"
        }
    }

    func deleteToDo(_ todo: ToDo) async {
        do {
            try await removeToDoUseCase.execute(toDoID: todo.id)
            await reloadCurrent()
        } catch {
            errorMessage = "Task remove failed: \(error.localizedDescription)"
        }
    }

    func restoreToDo(_ todo: ToDo) async {
        do {
            try await restoreToDoUseCase.execute(toDoID: todo.id)
            await reloadCurrent()
        } catch {
            errorMessage = "Task restore failed: \(error.localizedDescription)"
        }
    }

    func removeToDo(_ todo: ToDo) async {
        do {
            try await removeToDoUseCase.execute(toDoID: todo.id)
            await reloadCurrent()
        } catch {
            errorMessage = "Task remove failed: \(error.localizedDescription)"
        }
    }

    func moveToDo(_ todo: ToDo, direction: NoteTaskMoveDirection) async {
        guard let snapshot else { return }

        var orderedIDs = toDoItems.map(\.id)
        guard let index = orderedIDs.firstIndex(of: todo.id) else { return }
        let destination = direction == .up ? index - 1 : index + 1
        guard orderedIDs.indices.contains(destination) else { return }

        orderedIDs.swapAt(index, destination)

        do {
            try await reorderToDosUseCase.execute(noteID: snapshot.note.id, orderedToDoIDs: orderedIDs)
            await reloadCurrent()
        } catch {
            errorMessage = "Task reorder failed: \(error.localizedDescription)"
        }
    }

    private func makeSnapshot(noteID: NoteID) async throws -> NoteSnapshot? {
        try await getNoteSnapshotUseCase.execute(noteID: noteID, includeSnippetCode: false)
    }

    private func resolveSnippet(_ snippet: NoteSnippet) async -> NoteSnippet? {
        if !snippet.code.isEmpty {
            return snippet
        }

        do {
            return try await attachmentsRepository.snippet(id: snippet.id)
        } catch {
            errorMessage = "Snippet load failed: \(error.localizedDescription)"
            return nil
        }
    }

    private func rebuildPresentationState() {
        guard let snapshot else {
            toDoItems = []
            deletedToDoItems = []
            attachmentItems = []
            snippetItems = []
            activeAttachmentEditDraft = nil
            return
        }

        let sortedTodos = snapshot.todos.sorted(by: ToDoSorting.note)
        let todoPresentation = ToDoPresentationBuilder.makeNoteItems(from: sortedTodos)
        toDoItems = todoPresentation.active
        deletedToDoItems = todoPresentation.deleted
        attachmentItems = snapshot.attachments.sorted(by: Self.attachmentSort).map { attachment in
            AttachmentPresentationBuilder.make(attachment: attachment, previewURL: nil)
        }
        snippetItems = snapshot.snippets.sorted(by: Self.snippetSort).map { snippet in
            SnippetPresentationBuilder.make(snippet: snippet)
        }
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

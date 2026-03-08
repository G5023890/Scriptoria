import Observation

@MainActor
@Observable
final class NoteDetailViewModel {
    var snapshot: NoteSnapshot?
    var attachmentItems: [AttachmentItem] = []
    var snippetItems: [SnippetItem] = []
    var mode: NoteDetailMode = .read
    var isLoading = false
    var activeAttachmentPreview: AttachmentPreviewState?
    var activeSnippetPreview: NoteSnippet?
    var errorMessage: String?

    private let getNoteSnapshotUseCase: GetNoteSnapshotUseCase
    private let deleteNoteUseCase: DeleteNoteUseCase
    private let restoreNoteUseCase: RestoreNoteUseCase
    private let togglePinUseCase: TogglePinUseCase
    private let toggleFavoriteUseCase: ToggleFavoriteUseCase
    private let removeAttachmentUseCase: RemoveAttachmentUseCase
    private let prepareAttachmentPreviewUseCase: PrepareAttachmentPreviewUseCase
    private let openAttachmentUseCase: OpenAttachmentUseCase
    private let copySnippetUseCase: CopySnippetUseCase
    private let fileService: any FileService
    let syntaxHighlightService: any SyntaxHighlightService

    init(
        getNoteSnapshotUseCase: GetNoteSnapshotUseCase,
        deleteNoteUseCase: DeleteNoteUseCase,
        restoreNoteUseCase: RestoreNoteUseCase,
        togglePinUseCase: TogglePinUseCase,
        toggleFavoriteUseCase: ToggleFavoriteUseCase,
        removeAttachmentUseCase: RemoveAttachmentUseCase,
        prepareAttachmentPreviewUseCase: PrepareAttachmentPreviewUseCase,
        openAttachmentUseCase: OpenAttachmentUseCase,
        copySnippetUseCase: CopySnippetUseCase,
        fileService: any FileService,
        syntaxHighlightService: any SyntaxHighlightService
    ) {
        self.getNoteSnapshotUseCase = getNoteSnapshotUseCase
        self.deleteNoteUseCase = deleteNoteUseCase
        self.restoreNoteUseCase = restoreNoteUseCase
        self.togglePinUseCase = togglePinUseCase
        self.toggleFavoriteUseCase = toggleFavoriteUseCase
        self.removeAttachmentUseCase = removeAttachmentUseCase
        self.prepareAttachmentPreviewUseCase = prepareAttachmentPreviewUseCase
        self.openAttachmentUseCase = openAttachmentUseCase
        self.copySnippetUseCase = copySnippetUseCase
        self.fileService = fileService
        self.syntaxHighlightService = syntaxHighlightService
    }

    func load(noteID: NoteID?, preserveMode: Bool = false) async {
        guard let noteID else {
            snapshot = nil
            mode = .read
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
            let nextMode: NoteDetailMode = isReloadingSameNote ? preservedMode : .read
            mode = nextMode
            snapshot = nextSnapshot
            rebuildPresentationState()
        } catch {
            snapshot = nil
            mode = .read
            attachmentItems = []
            snippetItems = []
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

    func copySnippet(_ snippet: NoteSnippet) {
        copySnippetUseCase.execute(snippet: snippet)
    }

    func previewSnippet(_ snippet: NoteSnippet) {
        activeSnippetPreview = snippet
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

    private func makeSnapshot(noteID: NoteID) async throws -> NoteSnapshot? {
        try await getNoteSnapshotUseCase.execute(noteID: noteID)
    }

    private func rebuildPresentationState() {
        guard let snapshot else {
            attachmentItems = []
            snippetItems = []
            return
        }

        attachmentItems = snapshot.attachments.map { attachment in
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
        snippetItems = snapshot.snippets.map { snippet in
            SnippetPresentationBuilder.make(snippet: snippet, syntaxHighlightService: syntaxHighlightService)
        }
    }
}

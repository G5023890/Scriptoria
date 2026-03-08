import Foundation

@MainActor
extension AppEnvironment {
    func makeSidebarViewModel(onEmptyTrashRequested: @escaping @MainActor () -> Void) -> SidebarViewModel {
        SidebarViewModel(
            loadSidebarDataUseCase: loadSidebarDataUseCase,
            onEmptyTrashRequested: onEmptyTrashRequested
        )
    }

    func makeNotesListViewModel() -> NotesListViewModel {
        NotesListViewModel(
            listNoteSnapshotsUseCase: listNoteSnapshotsUseCase,
            getNoteSnapshotUseCase: getNoteSnapshotUseCase
        )
    }

    func makeNoteDetailViewModel() -> NoteDetailViewModel {
        NoteDetailViewModel(
            getNoteSnapshotUseCase: getNoteSnapshotUseCase,
            deleteNoteUseCase: deleteNoteUseCase,
            restoreNoteUseCase: restoreNoteUseCase,
            togglePinUseCase: togglePinUseCase,
            toggleFavoriteUseCase: toggleFavoriteUseCase,
            removeAttachmentUseCase: removeAttachmentUseCase,
            prepareAttachmentPreviewUseCase: prepareAttachmentPreviewUseCase,
            openAttachmentUseCase: openAttachmentUseCase,
            copySnippetUseCase: copySnippetUseCase,
            fileService: fileService,
            syntaxHighlightService: syntaxHighlightService
        )
    }

    func makeNoteEditorViewModel(noteID: NoteID, onSave: @escaping @MainActor () async -> Void) -> NoteEditorViewModel {
        NoteEditorViewModel(
            noteID: noteID,
            loadNoteDraftUseCase: loadNoteDraftUseCase,
            listLabelsUseCase: listLabelsUseCase,
            createLabelUseCase: createLabelUseCase,
            updateNoteUseCase: updateNoteUseCase,
            createManualSnippetUseCase: createManualSnippetUseCase,
            updateManualSnippetUseCase: updateManualSnippetUseCase,
            removeSnippetUseCase: removeSnippetUseCase,
            importAttachmentUseCase: importAttachmentUseCase,
            removeAttachmentUseCase: removeAttachmentUseCase,
            prepareAttachmentPreviewUseCase: prepareAttachmentPreviewUseCase,
            openAttachmentUseCase: openAttachmentUseCase,
            copySnippetUseCase: copySnippetUseCase,
            fileService: fileService,
            syntaxHighlightService: syntaxHighlightService,
            onSave: onSave
        )
    }

    func makeSearchViewModel() -> SearchViewModel {
        SearchViewModel(searchNotesUseCase: searchNotesUseCase)
    }

    func makeQuickCaptureViewModel() -> QuickCaptureViewModel {
        QuickCaptureViewModel(
            listLabelsUseCase: listLabelsUseCase,
            quickCaptureUseCase: quickCaptureUseCase
        )
    }
}

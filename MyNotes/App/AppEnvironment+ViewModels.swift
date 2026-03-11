import Foundation

@MainActor
extension AppEnvironment {
    func makeSidebarViewModel(onEmptyTrashRequested: @escaping @MainActor () -> Void) -> SidebarViewModel {
        SidebarViewModel(
            loadSidebarDataUseCase: loadSidebarDataUseCase,
            renameLabelUseCase: renameLabelUseCase,
            deleteLabelUseCase: deleteLabelUseCase,
            onEmptyTrashRequested: onEmptyTrashRequested
        )
    }

    func makeNotesListViewModel() -> NotesListViewModel {
        NotesListViewModel(
            listNoteSnapshotsUseCase: listNoteSnapshotsUseCase,
            getNoteSnapshotUseCase: getNoteSnapshotUseCase
        )
    }

    func makeToDosListViewModel() -> ToDosListViewModel {
        ToDosListViewModel(listAllToDosUseCase: listAllToDosUseCase)
    }

    func makeNoteDetailViewModel() -> NoteDetailViewModel {
        NoteDetailViewModel(
            getNoteSnapshotUseCase: getNoteSnapshotUseCase,
            listLabelsUseCase: listLabelsUseCase,
            createLabelUseCase: createLabelUseCase,
            assignLabelsUseCase: assignLabelsUseCase,
            deleteNoteUseCase: deleteNoteUseCase,
            restoreNoteUseCase: restoreNoteUseCase,
            togglePinUseCase: togglePinUseCase,
            toggleFavoriteUseCase: toggleFavoriteUseCase,
            createToDoUseCase: createToDoUseCase,
            updateToDoUseCase: updateToDoUseCase,
            deleteToDoUseCase: deleteToDoUseCase,
            removeToDoUseCase: removeToDoUseCase,
            restoreToDoUseCase: restoreToDoUseCase,
            completeToDoUseCase: completeToDoUseCase,
            reorderToDosUseCase: reorderToDosUseCase,
            importAttachmentUseCase: importAttachmentUseCase,
            createManualSnippetUseCase: createManualSnippetUseCase,
            removeAttachmentUseCase: removeAttachmentUseCase,
            prepareAttachmentPreviewUseCase: prepareAttachmentPreviewUseCase,
            openAttachmentUseCase: openAttachmentUseCase,
            copySnippetUseCase: copySnippetUseCase,
            attachmentsRepository: attachmentsRepository,
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
            createToDoUseCase: createToDoUseCase,
            updateToDoUseCase: updateToDoUseCase,
            deleteToDoUseCase: deleteToDoUseCase,
            removeToDoUseCase: removeToDoUseCase,
            restoreToDoUseCase: restoreToDoUseCase,
            completeToDoUseCase: completeToDoUseCase,
            reorderToDosUseCase: reorderToDosUseCase,
            listToDosForNoteUseCase: listToDosForNoteUseCase,
            createManualSnippetUseCase: createManualSnippetUseCase,
            updateManualSnippetUseCase: updateManualSnippetUseCase,
            removeSnippetUseCase: removeSnippetUseCase,
            importAttachmentUseCase: importAttachmentUseCase,
            removeAttachmentUseCase: removeAttachmentUseCase,
            prepareAttachmentPreviewUseCase: prepareAttachmentPreviewUseCase,
            openAttachmentUseCase: openAttachmentUseCase,
            copySnippetUseCase: copySnippetUseCase,
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

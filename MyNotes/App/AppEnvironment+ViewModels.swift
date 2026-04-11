import Foundation

@MainActor
extension AppEnvironment {
    func makeSidebarViewModel(onEmptyTrashRequested: @escaping @MainActor () -> Void) -> SidebarViewModel {
        SidebarViewModel(
            loadSidebarDataUseCase: loadSidebarDataUseCase,
            updateLabelUseCase: updateLabelUseCase,
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
            updateAttachmentUseCase: updateAttachmentUseCase,
            createManualSnippetUseCase: createManualSnippetUseCase,
            removeAttachmentUseCase: removeAttachmentUseCase,
            prepareAttachmentPreviewUseCase: prepareAttachmentPreviewUseCase,
            openAttachmentUseCase: openAttachmentUseCase,
            copyAttachmentUseCase: copyAttachmentUseCase,
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
            archiveSnippetUseCase: archiveSnippetUseCase,
            removeSnippetUseCase: removeSnippetUseCase,
            importAttachmentUseCase: importAttachmentUseCase,
            updateAttachmentUseCase: updateAttachmentUseCase,
            archiveAttachmentUseCase: archiveAttachmentUseCase,
            removeAttachmentUseCase: removeAttachmentUseCase,
            prepareAttachmentPreviewUseCase: prepareAttachmentPreviewUseCase,
            openAttachmentUseCase: openAttachmentUseCase,
            copyAttachmentUseCase: copyAttachmentUseCase,
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

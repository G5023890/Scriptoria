import Foundation

final class AppEnvironment {
    let dateService: any DateService
    let markdownService: any MarkdownService
    let fileService: any FileService
    let clipboardService: any ClipboardService
    let syntaxHighlightService: any SyntaxHighlightService
    let quickLookService: any QuickLookService
    let toDoNotificationScheduler: any ToDoNotificationScheduling
    let databaseManager: DatabaseManager

    let notesRepository: any NotesRepository
    let labelsRepository: any LabelsRepository
    let attachmentsRepository: any AttachmentsRepository
    let toDoRepository: any ToDoRepository
    let searchRepository: any SearchRepository
    let searchIndexRepository: any SearchIndexRepository
    let syncQueue: any SyncQueue
    let syncStateRepository: any SyncStateRepository
    let syncStatusStore: SyncStatusStore
    let conflictResolver: ConflictResolver
    let cloudKitSyncEngine: any CloudKitSyncEngine

    let searchPolicy: SearchPolicy
    let snippetDetectionPolicy: SnippetDetectionPolicy

    let listLabelsUseCase: ListLabelsUseCase
    let createLabelUseCase: CreateLabelUseCase
    let updateLabelUseCase: UpdateLabelUseCase
    let deleteLabelUseCase: DeleteLabelUseCase
    let loadSidebarDataUseCase: LoadSidebarDataUseCase
    let getNoteSnapshotUseCase: GetNoteSnapshotUseCase
    let listNoteSnapshotsUseCase: ListNoteSnapshotsUseCase
    let loadNoteDraftUseCase: LoadNoteDraftUseCase
    let indexNoteForSearchUseCase: IndexNoteForSearchUseCase
    let createNoteUseCase: CreateNoteUseCase
    let updateNoteUseCase: UpdateNoteUseCase
    let deleteNoteUseCase: DeleteNoteUseCase
    let emptyTrashUseCase: EmptyTrashUseCase
    let restoreNoteUseCase: RestoreNoteUseCase
    let searchNotesUseCase: SearchNotesUseCase
    let togglePinUseCase: TogglePinUseCase
    let toggleFavoriteUseCase: ToggleFavoriteUseCase
    let assignLabelsUseCase: AssignLabelsUseCase
    let createToDoUseCase: CreateToDoUseCase
    let updateToDoUseCase: UpdateToDoUseCase
    let deleteToDoUseCase: DeleteToDoUseCase
    let removeToDoUseCase: RemoveToDoUseCase
    let restoreToDoUseCase: RestoreToDoUseCase
    let completeToDoUseCase: CompleteToDoUseCase
    let snoozeToDoUseCase: SnoozeToDoUseCase
    let reorderToDosUseCase: ReorderToDosUseCase
    let listToDosForNoteUseCase: ListToDosForNoteUseCase
    let listAllToDosUseCase: ListAllToDosUseCase
    let refreshToDoNotificationsUseCase: RefreshToDoNotificationsUseCase
    let importAttachmentUseCase: ImportAttachmentUseCase
    let updateAttachmentUseCase: UpdateAttachmentUseCase
    let createSnippetUseCase: CreateSnippetUseCase
    let createManualSnippetUseCase: CreateManualSnippetUseCase
    let updateManualSnippetUseCase: UpdateManualSnippetUseCase
    let archiveSnippetUseCase: ArchiveSnippetUseCase
    let removeSnippetUseCase: RemoveSnippetUseCase
    let archiveAttachmentUseCase: ArchiveAttachmentUseCase
    let removeAttachmentUseCase: RemoveAttachmentUseCase
    let prepareAttachmentPreviewUseCase: PrepareAttachmentPreviewUseCase
    let openAttachmentUseCase: OpenAttachmentUseCase
    let copySnippetUseCase: CopySnippetUseCase
    let quickCaptureUseCase: QuickCaptureUseCase
    let seedSampleDataUseCase: SeedSampleDataUseCase
    let bootstrapApplicationUseCase: BootstrapApplicationUseCase

    init(
        dateService: any DateService,
        markdownService: any MarkdownService,
        fileService: any FileService,
        clipboardService: any ClipboardService,
        syntaxHighlightService: any SyntaxHighlightService,
        quickLookService: any QuickLookService,
        toDoNotificationScheduler: any ToDoNotificationScheduling,
        databaseManager: DatabaseManager,
        notesRepository: any NotesRepository,
        labelsRepository: any LabelsRepository,
        attachmentsRepository: any AttachmentsRepository,
        toDoRepository: any ToDoRepository,
        searchRepository: any SearchRepository,
        searchIndexRepository: any SearchIndexRepository,
        syncQueue: any SyncQueue,
        syncStateRepository: any SyncStateRepository,
        syncStatusStore: SyncStatusStore,
        conflictResolver: ConflictResolver,
        cloudKitSyncEngine: any CloudKitSyncEngine,
        searchPolicy: SearchPolicy,
        snippetDetectionPolicy: SnippetDetectionPolicy,
        listLabelsUseCase: ListLabelsUseCase,
        createLabelUseCase: CreateLabelUseCase,
        updateLabelUseCase: UpdateLabelUseCase,
        deleteLabelUseCase: DeleteLabelUseCase,
        loadSidebarDataUseCase: LoadSidebarDataUseCase,
        getNoteSnapshotUseCase: GetNoteSnapshotUseCase,
        listNoteSnapshotsUseCase: ListNoteSnapshotsUseCase,
        loadNoteDraftUseCase: LoadNoteDraftUseCase,
        indexNoteForSearchUseCase: IndexNoteForSearchUseCase,
        createNoteUseCase: CreateNoteUseCase,
        updateNoteUseCase: UpdateNoteUseCase,
        deleteNoteUseCase: DeleteNoteUseCase,
        emptyTrashUseCase: EmptyTrashUseCase,
        restoreNoteUseCase: RestoreNoteUseCase,
        searchNotesUseCase: SearchNotesUseCase,
        togglePinUseCase: TogglePinUseCase,
        toggleFavoriteUseCase: ToggleFavoriteUseCase,
        assignLabelsUseCase: AssignLabelsUseCase,
        createToDoUseCase: CreateToDoUseCase,
        updateToDoUseCase: UpdateToDoUseCase,
        deleteToDoUseCase: DeleteToDoUseCase,
        removeToDoUseCase: RemoveToDoUseCase,
        restoreToDoUseCase: RestoreToDoUseCase,
        completeToDoUseCase: CompleteToDoUseCase,
        snoozeToDoUseCase: SnoozeToDoUseCase,
        reorderToDosUseCase: ReorderToDosUseCase,
        listToDosForNoteUseCase: ListToDosForNoteUseCase,
        listAllToDosUseCase: ListAllToDosUseCase,
        refreshToDoNotificationsUseCase: RefreshToDoNotificationsUseCase,
        importAttachmentUseCase: ImportAttachmentUseCase,
        updateAttachmentUseCase: UpdateAttachmentUseCase,
        createSnippetUseCase: CreateSnippetUseCase,
        createManualSnippetUseCase: CreateManualSnippetUseCase,
        updateManualSnippetUseCase: UpdateManualSnippetUseCase,
        archiveSnippetUseCase: ArchiveSnippetUseCase,
        removeSnippetUseCase: RemoveSnippetUseCase,
        archiveAttachmentUseCase: ArchiveAttachmentUseCase,
        removeAttachmentUseCase: RemoveAttachmentUseCase,
        prepareAttachmentPreviewUseCase: PrepareAttachmentPreviewUseCase,
        openAttachmentUseCase: OpenAttachmentUseCase,
        copySnippetUseCase: CopySnippetUseCase,
        quickCaptureUseCase: QuickCaptureUseCase,
        seedSampleDataUseCase: SeedSampleDataUseCase,
        bootstrapApplicationUseCase: BootstrapApplicationUseCase
    ) {
        self.dateService = dateService
        self.markdownService = markdownService
        self.fileService = fileService
        self.clipboardService = clipboardService
        self.syntaxHighlightService = syntaxHighlightService
        self.quickLookService = quickLookService
        self.toDoNotificationScheduler = toDoNotificationScheduler
        self.databaseManager = databaseManager
        self.notesRepository = notesRepository
        self.labelsRepository = labelsRepository
        self.attachmentsRepository = attachmentsRepository
        self.toDoRepository = toDoRepository
        self.searchRepository = searchRepository
        self.searchIndexRepository = searchIndexRepository
        self.syncQueue = syncQueue
        self.syncStateRepository = syncStateRepository
        self.syncStatusStore = syncStatusStore
        self.conflictResolver = conflictResolver
        self.cloudKitSyncEngine = cloudKitSyncEngine
        self.searchPolicy = searchPolicy
        self.snippetDetectionPolicy = snippetDetectionPolicy
        self.listLabelsUseCase = listLabelsUseCase
        self.createLabelUseCase = createLabelUseCase
        self.updateLabelUseCase = updateLabelUseCase
        self.deleteLabelUseCase = deleteLabelUseCase
        self.loadSidebarDataUseCase = loadSidebarDataUseCase
        self.getNoteSnapshotUseCase = getNoteSnapshotUseCase
        self.listNoteSnapshotsUseCase = listNoteSnapshotsUseCase
        self.loadNoteDraftUseCase = loadNoteDraftUseCase
        self.indexNoteForSearchUseCase = indexNoteForSearchUseCase
        self.createNoteUseCase = createNoteUseCase
        self.updateNoteUseCase = updateNoteUseCase
        self.deleteNoteUseCase = deleteNoteUseCase
        self.emptyTrashUseCase = emptyTrashUseCase
        self.restoreNoteUseCase = restoreNoteUseCase
        self.searchNotesUseCase = searchNotesUseCase
        self.togglePinUseCase = togglePinUseCase
        self.toggleFavoriteUseCase = toggleFavoriteUseCase
        self.assignLabelsUseCase = assignLabelsUseCase
        self.createToDoUseCase = createToDoUseCase
        self.updateToDoUseCase = updateToDoUseCase
        self.deleteToDoUseCase = deleteToDoUseCase
        self.removeToDoUseCase = removeToDoUseCase
        self.restoreToDoUseCase = restoreToDoUseCase
        self.completeToDoUseCase = completeToDoUseCase
        self.snoozeToDoUseCase = snoozeToDoUseCase
        self.reorderToDosUseCase = reorderToDosUseCase
        self.listToDosForNoteUseCase = listToDosForNoteUseCase
        self.listAllToDosUseCase = listAllToDosUseCase
        self.refreshToDoNotificationsUseCase = refreshToDoNotificationsUseCase
        self.importAttachmentUseCase = importAttachmentUseCase
        self.updateAttachmentUseCase = updateAttachmentUseCase
        self.createSnippetUseCase = createSnippetUseCase
        self.createManualSnippetUseCase = createManualSnippetUseCase
        self.updateManualSnippetUseCase = updateManualSnippetUseCase
        self.archiveSnippetUseCase = archiveSnippetUseCase
        self.removeSnippetUseCase = removeSnippetUseCase
        self.archiveAttachmentUseCase = archiveAttachmentUseCase
        self.removeAttachmentUseCase = removeAttachmentUseCase
        self.prepareAttachmentPreviewUseCase = prepareAttachmentPreviewUseCase
        self.openAttachmentUseCase = openAttachmentUseCase
        self.copySnippetUseCase = copySnippetUseCase
        self.quickCaptureUseCase = quickCaptureUseCase
        self.seedSampleDataUseCase = seedSampleDataUseCase
        self.bootstrapApplicationUseCase = bootstrapApplicationUseCase
    }
}

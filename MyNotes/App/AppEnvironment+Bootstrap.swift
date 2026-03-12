import Foundation

extension AppEnvironment {
    @MainActor
    static func bootstrap() -> AppEnvironment {
        let dateService = SystemDateService()
        let markdownService = DefaultMarkdownService()
        let fileService = LocalFileService()
        let clipboardService = SystemClipboardService()
        let quickLookService = DefaultQuickLookService(fileService: fileService)
        let syntaxHighlightService = HighlightrSyntaxHighlightService()
        let toDoNotificationScheduler = LocalToDoNotificationScheduler()
        let databaseManager = DatabaseManager(fileService: fileService)

        let notesDataSource = NotesLocalDataSource(databaseManager: databaseManager)
        let labelsDataSource = LabelsLocalDataSource(databaseManager: databaseManager)
        let attachmentsDataSource = AttachmentsLocalDataSource(databaseManager: databaseManager)
        let toDoDataSource = ToDoLocalDataSource(databaseManager: databaseManager)
        let searchDataSource = SearchLocalDataSource(databaseManager: databaseManager)
        let syncDataSource = SyncLocalDataSource(databaseManager: databaseManager)

        let localNotesRepository = LocalNotesRepository(dataSource: notesDataSource)
        let localLabelsRepository = LocalLabelsRepository(dataSource: labelsDataSource)
        let localAttachmentsRepository = LocalAttachmentsRepository(
            dataSource: attachmentsDataSource,
            fileService: fileService,
            dateService: dateService
        )
        let toDoRepository = LocalToDoRepository(dataSource: toDoDataSource)
        let searchIndexRepository = LocalSearchIndexRepository(dataSource: searchDataSource)
        let searchPolicy = SearchPolicy()
        let searchRepository = LocalSearchRepository(
            dataSource: searchDataSource,
            searchPolicy: searchPolicy
        )
        let syncStatusStore = SyncStatusStore()
        let syncQueue = LocalSyncQueue(dataSource: syncDataSource, dateService: dateService)
        let syncStateRepository = LocalSyncStateRepository(dataSource: syncDataSource, dateService: dateService)
        let conflictResolver = ConflictResolver()
        let syncMapper = SyncMapper()
        let cloudKitSyncEngine = DefaultCloudKitSyncEngine(
            configuration: .disabled,
            syncQueue: syncQueue,
            syncStateRepository: syncStateRepository,
            syncMapper: syncMapper,
            conflictResolver: conflictResolver,
            notesDataSource: notesDataSource,
            labelsDataSource: labelsDataSource,
            attachmentsDataSource: attachmentsDataSource,
            syncStatusStore: syncStatusStore,
            dateService: dateService
        )
        let notesRepository = SyncAwareNotesRepository(base: localNotesRepository, syncQueue: syncQueue)
        let labelsRepository = SyncAwareLabelsRepository(base: localLabelsRepository, syncQueue: syncQueue)
        let attachmentsRepository = SyncAwareAttachmentsRepository(base: localAttachmentsRepository, syncQueue: syncQueue)
        let snippetDetectionPolicy = SnippetDetectionPolicy(markdownService: markdownService)

        let listLabelsUseCase = ListLabelsUseCase(labelsRepository: labelsRepository)
        let createLabelUseCase = CreateLabelUseCase(
            labelsRepository: labelsRepository,
            dateService: dateService
        )
        let updateLabelUseCase = UpdateLabelUseCase(
            labelsRepository: labelsRepository,
            dateService: dateService
        )
        let deleteLabelUseCase = DeleteLabelUseCase(
            labelsRepository: labelsRepository,
            dateService: dateService
        )
        let loadSidebarDataUseCase = LoadSidebarDataUseCase(
            notesRepository: notesRepository,
            labelsRepository: labelsRepository,
            attachmentsRepository: attachmentsRepository,
            toDoRepository: toDoRepository
        )
        let getNoteSnapshotUseCase = GetNoteSnapshotUseCase(
            notesRepository: notesRepository,
            labelsRepository: labelsRepository,
            attachmentsRepository: attachmentsRepository,
            toDoRepository: toDoRepository
        )
        let listNoteSnapshotsUseCase = ListNoteSnapshotsUseCase(
            notesRepository: notesRepository,
            labelsRepository: labelsRepository,
            attachmentsRepository: attachmentsRepository,
            toDoRepository: toDoRepository
        )
        let loadNoteDraftUseCase = LoadNoteDraftUseCase(getNoteSnapshotUseCase: getNoteSnapshotUseCase)
        let indexNoteForSearchUseCase = IndexNoteForSearchUseCase(
            getNoteSnapshotUseCase: getNoteSnapshotUseCase,
            searchIndexRepository: searchIndexRepository
        )
        let createSnippetUseCase = CreateSnippetUseCase(
            attachmentsRepository: attachmentsRepository,
            snippetDetectionPolicy: snippetDetectionPolicy,
            dateService: dateService,
            indexNoteForSearchUseCase: indexNoteForSearchUseCase
        )
        let createManualSnippetUseCase = CreateManualSnippetUseCase(
            attachmentsRepository: attachmentsRepository,
            indexNoteForSearchUseCase: indexNoteForSearchUseCase,
            dateService: dateService
        )
        let updateManualSnippetUseCase = UpdateManualSnippetUseCase(
            attachmentsRepository: attachmentsRepository,
            indexNoteForSearchUseCase: indexNoteForSearchUseCase,
            dateService: dateService
        )
        let removeSnippetUseCase = RemoveSnippetUseCase(
            attachmentsRepository: attachmentsRepository,
            indexNoteForSearchUseCase: indexNoteForSearchUseCase
        )
        let importAttachmentUseCase = ImportAttachmentUseCase(
            attachmentsRepository: attachmentsRepository,
            fileService: fileService,
            dateService: dateService,
            indexNoteForSearchUseCase: indexNoteForSearchUseCase
        )
        let removeAttachmentUseCase = RemoveAttachmentUseCase(
            attachmentsRepository: attachmentsRepository,
            indexNoteForSearchUseCase: indexNoteForSearchUseCase
        )
        let prepareAttachmentPreviewUseCase = PrepareAttachmentPreviewUseCase(
            quickLookService: quickLookService
        )
        let openAttachmentUseCase = OpenAttachmentUseCase(quickLookService: quickLookService)
        let copySnippetUseCase = CopySnippetUseCase(clipboardService: clipboardService)
        let refreshToDoNotificationsUseCase = RefreshToDoNotificationsUseCase(
            toDoRepository: toDoRepository,
            notificationScheduler: toDoNotificationScheduler
        )

        let createNoteUseCase = CreateNoteUseCase(
            notesRepository: notesRepository,
            markdownService: markdownService,
            dateService: dateService,
            indexNoteForSearchUseCase: indexNoteForSearchUseCase
        )
        let updateNoteUseCase = UpdateNoteUseCase(
            notesRepository: notesRepository,
            labelsRepository: labelsRepository,
            markdownService: markdownService,
            dateService: dateService,
            createSnippetUseCase: createSnippetUseCase,
            indexNoteForSearchUseCase: indexNoteForSearchUseCase,
            refreshToDoNotificationsUseCase: refreshToDoNotificationsUseCase
        )
        let deleteNoteUseCase = DeleteNoteUseCase(
            notesRepository: notesRepository,
            searchIndexRepository: searchIndexRepository,
            dateService: dateService,
            refreshToDoNotificationsUseCase: refreshToDoNotificationsUseCase
        )
        let emptyTrashUseCase = EmptyTrashUseCase(
            notesRepository: notesRepository,
            databaseManager: databaseManager,
            fileService: fileService,
            searchIndexRepository: searchIndexRepository,
            refreshToDoNotificationsUseCase: refreshToDoNotificationsUseCase
        )
        let restoreNoteUseCase = RestoreNoteUseCase(
            notesRepository: notesRepository,
            dateService: dateService,
            indexNoteForSearchUseCase: indexNoteForSearchUseCase,
            refreshToDoNotificationsUseCase: refreshToDoNotificationsUseCase
        )
        let searchNotesUseCase = SearchNotesUseCase(searchRepository: searchRepository, searchPolicy: searchPolicy)
        let togglePinUseCase = TogglePinUseCase(
            notesRepository: notesRepository,
            dateService: dateService,
            indexNoteForSearchUseCase: indexNoteForSearchUseCase
        )
        let toggleFavoriteUseCase = ToggleFavoriteUseCase(
            notesRepository: notesRepository,
            dateService: dateService,
            indexNoteForSearchUseCase: indexNoteForSearchUseCase
        )
        let assignLabelsUseCase = AssignLabelsUseCase(
            labelsRepository: labelsRepository,
            indexNoteForSearchUseCase: indexNoteForSearchUseCase
        )
        let createToDoUseCase = CreateToDoUseCase(
            toDoRepository: toDoRepository,
            dateService: dateService,
            refreshToDoNotificationsUseCase: refreshToDoNotificationsUseCase
        )
        let updateToDoUseCase = UpdateToDoUseCase(
            toDoRepository: toDoRepository,
            dateService: dateService,
            refreshToDoNotificationsUseCase: refreshToDoNotificationsUseCase
        )
        let deleteToDoUseCase = DeleteToDoUseCase(
            toDoRepository: toDoRepository,
            dateService: dateService,
            refreshToDoNotificationsUseCase: refreshToDoNotificationsUseCase
        )
        let removeToDoUseCase = RemoveToDoUseCase(
            toDoRepository: toDoRepository,
            refreshToDoNotificationsUseCase: refreshToDoNotificationsUseCase
        )
        let restoreToDoUseCase = RestoreToDoUseCase(
            toDoRepository: toDoRepository,
            dateService: dateService,
            refreshToDoNotificationsUseCase: refreshToDoNotificationsUseCase
        )
        let completeToDoUseCase = CompleteToDoUseCase(
            toDoRepository: toDoRepository,
            dateService: dateService,
            refreshToDoNotificationsUseCase: refreshToDoNotificationsUseCase
        )
        let snoozeToDoUseCase = SnoozeToDoUseCase(
            toDoRepository: toDoRepository,
            dateService: dateService,
            calendar: .current,
            refreshToDoNotificationsUseCase: refreshToDoNotificationsUseCase
        )
        let reorderToDosUseCase = ReorderToDosUseCase(
            toDoRepository: toDoRepository,
            dateService: dateService
        )
        let listToDosForNoteUseCase = ListToDosForNoteUseCase(toDoRepository: toDoRepository)
        let listAllToDosUseCase = ListAllToDosUseCase(
            toDoRepository: toDoRepository,
            calendar: .current,
            dateService: dateService
        )
        let quickCaptureUseCase = QuickCaptureUseCase(
            createNoteUseCase: createNoteUseCase,
            assignLabelsUseCase: assignLabelsUseCase,
            indexNoteForSearchUseCase: indexNoteForSearchUseCase
        )
        let seedSampleDataUseCase = SeedSampleDataUseCase(
            notesRepository: notesRepository,
            labelsRepository: labelsRepository,
            attachmentsRepository: attachmentsRepository,
            assignLabelsUseCase: assignLabelsUseCase,
            markdownService: markdownService,
            dateService: dateService,
            indexNoteForSearchUseCase: indexNoteForSearchUseCase
        )
        let bootstrapApplicationUseCase = BootstrapApplicationUseCase(
            databaseManager: databaseManager,
            seedSampleDataUseCase: seedSampleDataUseCase,
            refreshToDoNotificationsUseCase: refreshToDoNotificationsUseCase
        )

        return AppEnvironment(
            dateService: dateService,
            markdownService: markdownService,
            fileService: fileService,
            clipboardService: clipboardService,
            syntaxHighlightService: syntaxHighlightService,
            quickLookService: quickLookService,
            toDoNotificationScheduler: toDoNotificationScheduler,
            databaseManager: databaseManager,
            notesRepository: notesRepository,
            labelsRepository: labelsRepository,
            attachmentsRepository: attachmentsRepository,
            toDoRepository: toDoRepository,
            searchRepository: searchRepository,
            searchIndexRepository: searchIndexRepository,
            syncQueue: syncQueue,
            syncStateRepository: syncStateRepository,
            syncStatusStore: syncStatusStore,
            conflictResolver: conflictResolver,
            cloudKitSyncEngine: cloudKitSyncEngine,
            searchPolicy: searchPolicy,
            snippetDetectionPolicy: snippetDetectionPolicy,
            listLabelsUseCase: listLabelsUseCase,
            createLabelUseCase: createLabelUseCase,
            updateLabelUseCase: updateLabelUseCase,
            deleteLabelUseCase: deleteLabelUseCase,
            loadSidebarDataUseCase: loadSidebarDataUseCase,
            getNoteSnapshotUseCase: getNoteSnapshotUseCase,
            listNoteSnapshotsUseCase: listNoteSnapshotsUseCase,
            loadNoteDraftUseCase: loadNoteDraftUseCase,
            indexNoteForSearchUseCase: indexNoteForSearchUseCase,
            createNoteUseCase: createNoteUseCase,
            updateNoteUseCase: updateNoteUseCase,
            deleteNoteUseCase: deleteNoteUseCase,
            emptyTrashUseCase: emptyTrashUseCase,
            restoreNoteUseCase: restoreNoteUseCase,
            searchNotesUseCase: searchNotesUseCase,
            togglePinUseCase: togglePinUseCase,
            toggleFavoriteUseCase: toggleFavoriteUseCase,
            assignLabelsUseCase: assignLabelsUseCase,
            createToDoUseCase: createToDoUseCase,
            updateToDoUseCase: updateToDoUseCase,
            deleteToDoUseCase: deleteToDoUseCase,
            removeToDoUseCase: removeToDoUseCase,
            restoreToDoUseCase: restoreToDoUseCase,
            completeToDoUseCase: completeToDoUseCase,
            snoozeToDoUseCase: snoozeToDoUseCase,
            reorderToDosUseCase: reorderToDosUseCase,
            listToDosForNoteUseCase: listToDosForNoteUseCase,
            listAllToDosUseCase: listAllToDosUseCase,
            refreshToDoNotificationsUseCase: refreshToDoNotificationsUseCase,
            importAttachmentUseCase: importAttachmentUseCase,
            createSnippetUseCase: createSnippetUseCase,
            createManualSnippetUseCase: createManualSnippetUseCase,
            updateManualSnippetUseCase: updateManualSnippetUseCase,
            removeSnippetUseCase: removeSnippetUseCase,
            removeAttachmentUseCase: removeAttachmentUseCase,
            prepareAttachmentPreviewUseCase: prepareAttachmentPreviewUseCase,
            openAttachmentUseCase: openAttachmentUseCase,
            copySnippetUseCase: copySnippetUseCase,
            quickCaptureUseCase: quickCaptureUseCase,
            seedSampleDataUseCase: seedSampleDataUseCase,
            bootstrapApplicationUseCase: bootstrapApplicationUseCase
        )
    }

    func bootstrapSampleDataIfNeeded() async {
        await bootstrapApplicationUseCase.execute()
    }

    @MainActor
    func configureToDoNotificationRouting(
        onOpenToDo: @escaping @MainActor (NoteID, ToDoID) -> Void,
        onSnoozeToDo: @escaping @MainActor (ToDoID, ToDoNotificationSnoozePreset) async -> Void,
        onCompleteToDo: @escaping @MainActor (ToDoID) async -> Void
    ) {
        toDoNotificationScheduler.configure(
            onOpenToDo: onOpenToDo,
            onSnoozeToDo: onSnoozeToDo,
            onCompleteToDo: onCompleteToDo
        )
    }

    func refreshToDoNotifications(promptIfNeeded: Bool = false) async {
        await refreshToDoNotificationsUseCase.execute(promptIfNeeded: promptIfNeeded)
    }

    func completeToDoFromNotification(toDoID: ToDoID) async {
        do {
            try await completeToDoUseCase.execute(toDoID: toDoID, isCompleted: true)
        } catch {
            print("Notification completion failed: \(error)")
        }
    }

    func snoozeToDoFromNotification(
        toDoID: ToDoID,
        preset: ToDoNotificationSnoozePreset
    ) async {
        do {
            try await snoozeToDoUseCase.execute(toDoID: toDoID, preset: preset)
        } catch {
            print("Notification snooze failed: \(error)")
        }
    }

    func performSyncIfNeeded() async {
        await cloudKitSyncEngine.performSyncIfNeeded()
    }

    func processPendingSyncQueue() async {
        await cloudKitSyncEngine.processPendingSyncQueue()
    }
}

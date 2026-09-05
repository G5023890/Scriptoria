import Foundation
import Observation
import StoreKit

enum ScriptoriaProductID {
    static let proMonthly = "com.grigorym.Scriptoria.pro.monthly"
    static let proAnnual = "com.grigorym.Scriptoria.pro.annual"
    static let proLifetime = "com.grigorym.Scriptoria.pro.lifetime"

    static let proProducts: Set<String> = [
        proMonthly,
        proAnnual,
        proLifetime
    ]
}

enum ProAccessSource: String, Sendable {
    case checking
    case testFlight
    case development
    case subscription
    case lifetime
    case free
    case unavailable
}

@MainActor
@Observable
final class ProAccessStore {
    private(set) var isPro = true
    private(set) var source: ProAccessSource = .checking

    func refresh() async {
        do {
            let appTransaction = try await AppTransaction.shared
            switch appTransaction {
            case .verified(let transaction):
                if transaction.environment == .sandbox {
                    setAccess(isPro: true, source: .testFlight)
                    return
                }
                if transaction.environment == .xcode {
                    setAccess(isPro: true, source: .development)
                    return
                }
            case .unverified:
                break
            }

            for await entitlement in Transaction.currentEntitlements {
                guard case .verified(let transaction) = entitlement else { continue }
                guard ScriptoriaProductID.proProducts.contains(transaction.productID) else { continue }
                guard transaction.revocationDate == nil else { continue }

                let source: ProAccessSource = transaction.productID == ScriptoriaProductID.proLifetime
                    ? .lifetime
                    : .subscription
                setAccess(isPro: true, source: source)
                return
            }

            setAccess(isPro: false, source: .free)
        } catch {
            #if DEBUG
            setAccess(isPro: true, source: .development)
            #else
            setAccess(isPro: false, source: .unavailable)
            #endif
        }
    }

    private func setAccess(isPro: Bool, source: ProAccessSource) {
        self.isPro = isPro
        self.source = source
        NSLog("[ScriptoriaStore] Pro access=%@ source=%@", isPro.description, source.rawValue)
    }
}

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
    let proAccessStore: ProAccessStore
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
    let copyAttachmentUseCase: CopyAttachmentUseCase
    let copySnippetUseCase: CopySnippetUseCase
    let quickCaptureUseCase: QuickCaptureUseCase
    let seedSampleDataUseCase: SeedSampleDataUseCase
    let storageCleanupUseCase: StorageCleanupUseCase
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
        proAccessStore: ProAccessStore,
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
        copyAttachmentUseCase: CopyAttachmentUseCase,
        copySnippetUseCase: CopySnippetUseCase,
        quickCaptureUseCase: QuickCaptureUseCase,
        seedSampleDataUseCase: SeedSampleDataUseCase,
        storageCleanupUseCase: StorageCleanupUseCase,
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
        self.proAccessStore = proAccessStore
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
        self.copyAttachmentUseCase = copyAttachmentUseCase
        self.copySnippetUseCase = copySnippetUseCase
        self.quickCaptureUseCase = quickCaptureUseCase
        self.seedSampleDataUseCase = seedSampleDataUseCase
        self.storageCleanupUseCase = storageCleanupUseCase
        self.bootstrapApplicationUseCase = bootstrapApplicationUseCase
    }
}

extension AppEnvironment {
    /// Creates a portable archive. Passing ids limits the archive to those notes.
    func exportNotes(noteIDs: Set<NoteID>? = nil) async throws -> ScriptoriaTransferResult {
        let snapshots = try await listNoteSnapshotsUseCase.execute(
            collection: .allNotes,
            labelID: nil
        )
        let selectedSnapshots = snapshots.filter { snapshot in
            noteIDs?.contains(snapshot.note.id) ?? true
        }
        let labelIDs = Set(selectedSnapshots.flatMap { $0.labels.map(\.id) })
        let labels = (try await labelsRepository.allLabels()).filter { labelIDs.contains($0.id) }
        let notes = selectedSnapshots.map {
            ScriptoriaTransferNote(
                note: $0.note,
                labelIDs: $0.labels.map(\.id),
                todos: $0.todos,
                attachments: $0.attachments,
                snippets: $0.snippets
            )
        }
        return try ScriptoriaDataTransferService(fileService: fileService).export(notes: notes, labels: labels)
    }

    /// Merges a Scriptoria archive by stable IDs. A newer local record always wins.
    func importNotes(from archiveURL: URL, selectedNoteIDs: Set<NoteID>? = nil) async throws -> ScriptoriaImportResult {
        let scopedAccess = archiveURL.startAccessingSecurityScopedResource()
        defer {
            if scopedAccess { archiveURL.stopAccessingSecurityScopedResource() }
        }
        let transferService = ScriptoriaDataTransferService(fileService: fileService)
        let archive = try transferService.readManifest(from: archiveURL)
        defer { transferService.removeTemporaryDirectory(archive.directory) }

        for importedLabel in archive.manifest.labels where !importedLabel.isDeleted {
            if let localLabel = try await labelsRepository.label(id: importedLabel.id) {
                if importedLabel.updatedAt > localLabel.updatedAt || importedLabel.version > localLabel.version {
                    try await labelsRepository.update(label: importedLabel)
                }
            } else {
                try await labelsRepository.create(label: importedLabel)
            }
        }

        var importedNotes = 0
        var skippedNotes = 0
        var importedAttachments = 0
        for payload in archive.manifest.notes where selectedNoteIDs?.contains(payload.note.id) ?? true {
            if let localNote = try await notesRepository.note(id: payload.note.id),
               localNote.updatedAt > payload.note.updatedAt || localNote.version > payload.note.version {
                skippedNotes += 1
                continue
            }

            if try await notesRepository.note(id: payload.note.id) == nil {
                try await notesRepository.create(note: payload.note)
            } else {
                try await notesRepository.update(note: payload.note)
            }
            try await labelsRepository.assign(labelIDs: payload.labelIDs, to: payload.note.id)

            for todo in payload.todos where !todo.isDeleted {
                if let localTodo = try await toDoRepository.todo(id: todo.id) {
                    if todo.updatedAt > localTodo.updatedAt || todo.version > localTodo.version {
                        try await toDoRepository.update(todo: todo)
                    }
                } else {
                    try await toDoRepository.create(todo: todo)
                }
            }

            for attachment in payload.attachments where !attachment.isDeleted {
                if let localAttachment = try await attachmentsRepository.attachment(id: attachment.id),
                   localAttachment.updatedAt > attachment.updatedAt || localAttachment.version > attachment.version {
                    continue
                }
                try transferService.validateAndCopyAttachment(attachment, from: archive.directory)
                if try await attachmentsRepository.attachment(id: attachment.id) == nil {
                    try await attachmentsRepository.add(attachment: attachment)
                } else {
                    _ = try await attachmentsRepository.update(attachment: attachment)
                }
                importedAttachments += 1
            }

            let activeSnippets = payload.snippets.filter { !$0.isDeleted }
            if !activeSnippets.isEmpty {
                _ = try await attachmentsRepository.replaceSnippets(activeSnippets, for: payload.note.id)
            }
            try await indexNoteForSearchUseCase.execute(noteID: payload.note.id)
            importedNotes += 1
        }
        await refreshToDoNotifications()
        return ScriptoriaImportResult(
            importedNotes: importedNotes,
            skippedNotes: skippedNotes,
            importedAttachments: importedAttachments
        )
    }
}

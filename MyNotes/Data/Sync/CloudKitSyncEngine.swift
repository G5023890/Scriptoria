import CloudKit
import Foundation

protocol CloudKitSyncEngine: Sendable {
    func performSyncIfNeeded() async
    func processPendingSyncQueue() async
    func pullLatestChanges() async
}

struct CloudKitSyncConfiguration: Sendable {
    let isEnabled: Bool
    let containerIdentifier: String?
    let databaseScope: CKDatabase.Scope

    static let disabled = CloudKitSyncConfiguration(
        isEnabled: false,
        containerIdentifier: nil,
        databaseScope: .private
    )
}

enum SyncEngineError: LocalizedError {
    case cloudKitAccountUnavailable
    case invalidDatabaseScope
    case missingLocalEntity(SyncQueueItem.EntityType, String)
    case queueItemFailure(String)

    var errorDescription: String? {
        switch self {
        case .cloudKitAccountUnavailable:
            "iCloud account is unavailable"
        case .invalidDatabaseScope:
            "CloudKit sync currently supports only the private database"
        case .missingLocalEntity(let entityType, let entityID):
            "Missing local \(entityType.rawValue) \(entityID)"
        case .queueItemFailure(let message):
            message
        }
    }
}

actor DefaultCloudKitSyncEngine: CloudKitSyncEngine {
    private enum Constants {
        static let zoneName = "ScriptoriaZone"
        static let usesCustomZone = false
    }

    private enum TokenCodec {
        static func encode(_ token: CKServerChangeToken?) throws -> String? {
            guard let token else { return nil }
            let data = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            return data.base64EncodedString()
        }

        static func decode(_ rawValue: String?) throws -> CKServerChangeToken? {
            guard let rawValue, let data = Data(base64Encoded: rawValue) else { return nil }
            return try NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
        }
    }

    private let configuration: CloudKitSyncConfiguration
    private let syncQueue: any SyncQueue
    private let syncStateRepository: any SyncStateRepository
    private let syncMapper: SyncMapper
    private let conflictResolver: ConflictResolver
    private let notesDataSource: NotesLocalDataSource
    private let labelsDataSource: LabelsLocalDataSource
    private let attachmentsDataSource: AttachmentsLocalDataSource
    private let toDoDataSource: ToDoLocalDataSource
    private let fileService: any FileService
    private let searchIndexRepository: any SearchIndexRepository
    private let refreshToDoNotificationsUseCase: RefreshToDoNotificationsUseCase
    private let syncStatusStore: SyncStatusStore
    private let dateService: any DateService

    private var isSyncInProgress = false
    private var needsFollowUpSync = false

    init(
        configuration: CloudKitSyncConfiguration,
        syncQueue: any SyncQueue,
        syncStateRepository: any SyncStateRepository,
        syncMapper: SyncMapper,
        conflictResolver: ConflictResolver,
        notesDataSource: NotesLocalDataSource,
        labelsDataSource: LabelsLocalDataSource,
        attachmentsDataSource: AttachmentsLocalDataSource,
        toDoDataSource: ToDoLocalDataSource,
        fileService: any FileService,
        searchIndexRepository: any SearchIndexRepository,
        refreshToDoNotificationsUseCase: RefreshToDoNotificationsUseCase,
        syncStatusStore: SyncStatusStore,
        dateService: any DateService
    ) {
        self.configuration = configuration
        self.syncQueue = syncQueue
        self.syncStateRepository = syncStateRepository
        self.syncMapper = syncMapper
        self.conflictResolver = conflictResolver
        self.notesDataSource = notesDataSource
        self.labelsDataSource = labelsDataSource
        self.attachmentsDataSource = attachmentsDataSource
        self.toDoDataSource = toDoDataSource
        self.fileService = fileService
        self.searchIndexRepository = searchIndexRepository
        self.refreshToDoNotificationsUseCase = refreshToDoNotificationsUseCase
        self.syncStatusStore = syncStatusStore
        self.dateService = dateService
    }

    func performSyncIfNeeded() async {
        guard !isSyncInProgress else {
            needsFollowUpSync = true
            return
        }
        isSyncInProgress = true
        defer { isSyncInProgress = false }

        repeat {
            needsFollowUpSync = false

            let pendingCount = (try? await syncQueue.pendingCount()) ?? 0

            guard configuration.isEnabled else {
                await publishDisabledStatus(pendingCount: pendingCount)
                continue
            }

            do {
                try ensurePrivateDatabaseScope()
                try await ensureAccountAvailability()
            } catch {
                await publishStatus(.unavailable(error.localizedDescription))
                continue
            }

            await ensureDatabaseSubscriptionIfNeeded()

            await publishStatus(.syncing)

            do {
                try await ensureZoneExists()
                try await performInitialBootstrapIfNeeded()
                var shouldPurgeCloudKitCache = false
                if Constants.usesCustomZone {
                    try await processPendingSyncQueueCycle()
                    shouldPurgeCloudKitCache = try await pullLatestChangesCycle()
                } else {
                    shouldPurgeCloudKitCache = try await pullLatestChangesCycle()
                    try await processPendingSyncQueueCycle()
                }

                try await performStorageCleanup(purgeCloudKitAssetCache: shouldPurgeCloudKitCache)

                let now = dateService.now()
                try await syncStateRepository.setLastSuccessfulSyncDate(now)
                try await syncStateRepository.setValue(nil, for: .lastFailureSummary)
                await publishStatus(.success(now))
            } catch {
                try? await syncStateRepository.setValue(error.localizedDescription, for: .lastFailureSummary)
                await publishStatus(.failed(error.localizedDescription))
            }
        } while needsFollowUpSync
    }

    func processPendingSyncQueue() async {
        await performSyncIfNeeded()
    }

    func pullLatestChanges() async {
        await performSyncIfNeeded()
    }

    private func processPendingSyncQueueCycle() async throws {
        try await syncQueue.compactQueue()
        let items = try await syncQueue.pendingItems(limit: 100)
        var firstFailure: String?
        var processedAtLeastOneItem = false

        for item in items {
            let attemptedAt = dateService.now()
            do {
                try await syncQueue.markProcessing(itemID: item.id, attemptedAt: attemptedAt)
                try await push(queueItem: item)
                try await syncQueue.markSucceeded(itemID: item.id)
                processedAtLeastOneItem = true
            } catch {
                let diagnostic = diagnosticSummary(for: error, queueItem: item)
                try await syncQueue.markFailed(
                    itemID: item.id,
                    attemptedAt: attemptedAt,
                    errorSummary: diagnostic
                )
                print("CloudKit sync failure: \(diagnostic)")
                if firstFailure == nil {
                    firstFailure = diagnostic
                }
            }
        }

        if !processedAtLeastOneItem, let firstFailure {
            throw SyncEngineError.queueItemFailure(firstFailure)
        }
    }

    private func performInitialBootstrapIfNeeded() async throws {
        let hasCompletedInitialSync = try await syncStateRepository.value(for: .hasCompletedInitialCloudSync) == "1"
        guard !hasCompletedInitialSync else { return }

        if !Constants.usesCustomZone {
            try await enqueueLocalSnapshotForInitialUpload()
            try await syncStateRepository.setValue("1", for: .hasCompletedInitialCloudSync)
            return
        }

        _ = try await pullLatestChangesCycle(resetToken: true)
        try await enqueueLocalSnapshotForInitialUpload()
        try await syncStateRepository.setValue("1", for: .hasCompletedInitialCloudSync)
    }

    private func enqueueLocalSnapshotForInitialUpload() async throws {
        for note in try notesDataSource.allNotes() {
            _ = try await syncQueue.enqueuePendingLocalChange(
                SyncEnqueueRequest(entityType: .note, entityID: note.id.rawValue, operation: .update, payloadVersion: note.version)
            )
        }

        for label in try labelsDataSource.allLabelsIncludingDeleted() {
            _ = try await syncQueue.enqueuePendingLocalChange(
                SyncEnqueueRequest(entityType: .label, entityID: label.id.rawValue, operation: .update, payloadVersion: label.version)
            )
        }

        for toDo in try toDoDataSource.allToDosIncludingDeleted() {
            _ = try await syncQueue.enqueuePendingLocalChange(
                SyncEnqueueRequest(entityType: .toDo, entityID: toDo.id.rawValue, operation: .update, payloadVersion: toDo.version)
            )
        }

        for attachment in try attachmentsDataSource.allAttachmentsIncludingDeleted() {
            _ = try await syncQueue.enqueuePendingLocalChange(
                SyncEnqueueRequest(entityType: .attachment, entityID: attachment.id.rawValue, operation: .update, payloadVersion: attachment.version)
            )
        }

        for snippet in try attachmentsDataSource.allSnippetsIncludingDeleted() {
            _ = try await syncQueue.enqueuePendingLocalChange(
                SyncEnqueueRequest(entityType: .snippet, entityID: snippet.id, operation: .update, payloadVersion: snippet.version)
            )
        }

        let assignments = Set(try labelsDataSource.allNoteLabelAssignments().map(\.noteID))
        for noteID in assignments {
            _ = try await syncQueue.enqueuePendingLocalChange(
                SyncEnqueueRequest(entityType: .noteLabel, entityID: noteID.rawValue, operation: .update, payloadVersion: 1)
            )
        }
    }

    private func pullLatestChangesCycle(resetToken: Bool = false) async throws -> Bool {
        guard Constants.usesCustomZone else {
            if resetToken {
                try await syncStateRepository.setValue(nil, for: .zoneChangeToken)
            }
            return try await pullFullSnapshotCycle()
        }

        let currentToken: CKServerChangeToken?
        if resetToken {
            currentToken = nil
        } else {
            currentToken = try TokenCodec.decode(try await syncStateRepository.value(for: .zoneChangeToken))
        }

        let response = try await fetchZoneChanges(since: currentToken)
        let changedRecords = response.changed.sorted { lhs, rhs in
            sortOrder(for: lhs.recordType) < sortOrder(for: rhs.recordType)
        }

        var affectedNoteIDs = Set<NoteID>()
        var shouldRefreshNotifications = false
        var didApplyAttachmentPayload = false

        for record in changedRecords {
            let appliedNoteIDs = try await applyChangedRecord(record)
            affectedNoteIDs.formUnion(appliedNoteIDs)
            if record.recordType == SyncMapper.RecordType.toDo {
                shouldRefreshNotifications = true
            }
            if record.recordType == SyncMapper.RecordType.attachment {
                didApplyAttachmentPayload = true
            }
        }

        for deletedRecordID in response.deleted {
            let deletedNoteIDs = try await applyDeletedRecord(recordID: deletedRecordID)
            affectedNoteIDs.formUnion(deletedNoteIDs)
        }

        try await syncStateRepository.setValue(try TokenCodec.encode(response.newToken), for: .zoneChangeToken)
        try await refreshDerivedState(for: affectedNoteIDs)

        if shouldRefreshNotifications {
            await refreshToDoNotificationsUseCase.execute(promptIfNeeded: false)
        }
        return didApplyAttachmentPayload
    }

    private func pullFullSnapshotCycle() async throws -> Bool {
        let notes = try await fetchAllRecordsAllowingEmptyType(ofType: SyncMapper.RecordType.note)
        let labels = try await fetchAllRecordsAllowingEmptyType(ofType: SyncMapper.RecordType.label)
        let toDos = try await fetchAllRecordsAllowingEmptyType(ofType: SyncMapper.RecordType.toDo)
        let attachments = try await fetchAllRecordsAllowingEmptyType(ofType: SyncMapper.RecordType.attachment)
        let snippets = try await fetchAllRecordsAllowingEmptyType(ofType: SyncMapper.RecordType.snippet)
        let noteLabels = try await fetchAllRecordsAllowingEmptyType(ofType: SyncMapper.RecordType.noteLabel)

        var affectedNoteIDs = Set<NoteID>()
        var shouldRefreshNotifications = false
        var didApplyAttachmentPayload = false

        let orderedRecords = notes + labels + toDos + attachments + snippets
        for record in orderedRecords {
            let appliedNoteIDs = try await applyChangedRecord(record)
            affectedNoteIDs.formUnion(appliedNoteIDs)
            if record.recordType == SyncMapper.RecordType.toDo {
                shouldRefreshNotifications = true
            }
            if record.recordType == SyncMapper.RecordType.attachment {
                didApplyAttachmentPayload = true
            }
        }

        let noteLabelNoteIDs = try await reconcileNoteLabelAssignments(with: noteLabels)
        affectedNoteIDs.formUnion(noteLabelNoteIDs)

        try await refreshDerivedState(for: affectedNoteIDs)

        if shouldRefreshNotifications {
            await refreshToDoNotificationsUseCase.execute(promptIfNeeded: false)
        }
        return didApplyAttachmentPayload
    }

    private func push(queueItem item: SyncQueueItem) async throws {
        switch item.entityType {
        case .note:
            let noteID = NoteID(rawValue: item.entityID)
            guard let note = try notesDataSource.note(id: noteID) else {
                guard item.operation == .delete else { return }
                try await push(records: [], deleting: [syncMapper.recordID(for: .note, entityID: item.entityID, zoneID: activeZoneID)])
                return
            }
            try await push(records: [syncMapper.noteRecord(for: note, zoneID: activeZoneID)], deleting: [])

        case .label:
            let labelID = LabelID(rawValue: item.entityID)
            guard let label = try labelsDataSource.label(id: labelID) else {
                guard item.operation == .delete else { return }
                try await push(records: [], deleting: [syncMapper.recordID(for: .label, entityID: item.entityID, zoneID: activeZoneID)])
                return
            }
            try await push(records: [syncMapper.labelRecord(for: label, zoneID: activeZoneID)], deleting: [])

        case .toDo:
            let toDoID = ToDoID(rawValue: item.entityID)
            guard let toDo = try toDoDataSource.todo(id: toDoID) else {
                guard item.operation == .delete else { return }
                try await push(records: [], deleting: [syncMapper.recordID(for: .toDo, entityID: item.entityID, zoneID: activeZoneID)])
                return
            }
            try await push(records: [syncMapper.toDoRecord(for: toDo, zoneID: activeZoneID)], deleting: [])

        case .attachment:
            let attachmentID = AttachmentID(rawValue: item.entityID)
            guard let attachment = try attachmentsDataSource.attachment(id: attachmentID) else {
                guard item.operation == .delete else { return }
                try await push(records: [], deleting: [syncMapper.recordID(for: .attachment, entityID: item.entityID, zoneID: activeZoneID)])
                return
            }

            let assetURL: URL?
            if attachment.isDeleted {
                assetURL = nil
            } else {
                assetURL = try? fileService.absoluteURL(for: attachment.relativePath)
            }
            try await push(records: [syncMapper.attachmentRecord(for: attachment, assetFileURL: assetURL, zoneID: activeZoneID)], deleting: [])

        case .snippet:
            guard let snippet = try attachmentsDataSource.snippet(id: item.entityID) else {
                guard item.operation == .delete else { return }
                try await push(records: [], deleting: [syncMapper.recordID(for: .snippet, entityID: item.entityID, zoneID: activeZoneID)])
                return
            }
            try await push(records: [syncMapper.snippetRecord(for: snippet, zoneID: activeZoneID)], deleting: [])

        case .noteLabel:
            let noteID = NoteID(rawValue: item.entityID)
            let note = try notesDataSource.note(id: noteID)
            let labels = try labelsDataSource.labels(for: noteID).map(\.id)
            let records = syncMapper.noteLabelRecords(
                noteID: noteID,
                labelIDs: labels,
                payloadVersion: note?.version ?? max(1, item.payloadVersion),
                updatedAt: note?.updatedAt ?? dateService.now(),
                zoneID: activeZoneID
            )
            try await push(records: records, deleting: [])
        }
    }

    private func push(records: [CKRecord], deleting recordIDs: [CKRecord.ID]) async throws {
        guard !records.isEmpty || !recordIDs.isEmpty else { return }
        _ = try await modifyRecords(records: records, deleting: recordIDs)
    }

    private func applyChangedRecord(_ record: CKRecord) async throws -> Set<NoteID> {
        switch record.recordType {
        case SyncMapper.RecordType.note:
            guard let payload = syncMapper.notePayload(from: record) else { return [] }
            if let local = try notesDataSource.note(id: payload.note.id) {
                let localLabels = try labelsDataSource.labels(for: payload.note.id).map(\.id)
                let remoteLabels = localLabels
                let localAttachments = try attachmentsDataSource.attachments(for: payload.note.id)
                let remoteAttachments = localAttachments
                let resolved = conflictResolver.resolveNote(
                    local: local,
                    remote: payload.note,
                    localLabels: localLabels,
                    remoteLabels: remoteLabels,
                    localAttachments: localAttachments,
                    remoteAttachments: remoteAttachments
                )
                try notesDataSource.update(resolved.note)
            } else {
                try notesDataSource.create(payload.note)
            }
            return [payload.note.id]

        case SyncMapper.RecordType.label:
            guard let payload = syncMapper.labelPayload(from: record) else { return [] }
            if let local = try labelsDataSource.label(id: payload.label.id) {
                try labelsDataSource.update(conflictResolver.resolveLabel(local: local, remote: payload.label))
            } else {
                try labelsDataSource.create(payload.label)
            }
            let affected = try labelsDataSource.noteIDs(for: payload.label.id)
            return Set(affected)

        case SyncMapper.RecordType.toDo:
            guard let payload = syncMapper.toDoPayload(from: record) else { return [] }
            if let local = try toDoDataSource.todo(id: payload.toDo.id) {
                try toDoDataSource.update(conflictResolver.resolveToDo(local: local, remote: payload.toDo))
            } else {
                try toDoDataSource.create(payload.toDo)
            }
            return [payload.toDo.noteID]

        case SyncMapper.RecordType.attachment:
            guard let payload = syncMapper.attachmentPayload(from: record) else { return [] }
            let existingAttachment = try attachmentsDataSource.attachment(id: payload.attachment.id)
            let resolvedAttachment: Attachment
            if let existingAttachment {
                resolvedAttachment = conflictResolver.resolveAttachment(local: existingAttachment, remote: payload.attachment)
                _ = try attachmentsDataSource.update(resolvedAttachment)
            } else {
                resolvedAttachment = payload.attachment
                try attachmentsDataSource.add(resolvedAttachment)
            }

            if resolvedAttachment.isDeleted {
                try? fileService.deleteItem(atRelativePath: resolvedAttachment.relativePath)
            } else if
                let assetURL = payload.asset?.fileURL,
                shouldWriteDownloadedAsset(
                    existingAttachment: existingAttachment,
                    resolvedAttachment: resolvedAttachment
                ) {
                try fileService.writeFile(atRelativePath: resolvedAttachment.relativePath, from: assetURL)
            }
            return [resolvedAttachment.noteID]

        case SyncMapper.RecordType.snippet:
            guard let payload = syncMapper.snippetPayload(from: record) else { return [] }
            let existing = try attachmentsDataSource.snippet(id: payload.snippet.id)
            if existing != nil {
                try attachmentsDataSource.saveSnippet(
                    conflictResolver.resolveSnippet(local: existing!, remote: payload.snippet)
                )
            } else {
                try attachmentsDataSource.saveSnippet(payload.snippet)
            }
            return [payload.snippet.noteID]

        case SyncMapper.RecordType.noteLabel:
            guard let payload = syncMapper.noteLabelPayload(from: record) else { return [] }
            try labelsDataSource.add(labelID: payload.labelID, to: payload.noteID)
            return [payload.noteID]

        default:
            return []
        }
    }

    private func applyDeletedRecord(recordID: CKRecord.ID) async throws -> Set<NoteID> {
        let recordName = recordID.recordName

        if recordName.hasPrefix("noteLabel.") {
            let parts = recordName.split(separator: ".")
            guard parts.count == 3 else { return [] }
            let noteID = NoteID(rawValue: String(parts[1]))
            let labelID = LabelID(rawValue: String(parts[2]))
            try labelsDataSource.remove(labelID: labelID, from: noteID)
            return [noteID]
        }

        if recordName.hasPrefix("note.") {
            let noteID = NoteID(rawValue: String(recordName.dropFirst(5)))
            try notesDataSource.softDelete(noteID: noteID, deletedAt: dateService.now())
            return [noteID]
        }

        if recordName.hasPrefix("label.") {
            let labelID = LabelID(rawValue: String(recordName.dropFirst(6)))
            let noteIDs = try labelsDataSource.noteIDs(for: labelID)
            try labelsDataSource.delete(labelID: labelID, deletedAt: dateService.now())
            return Set(noteIDs)
        }

        if recordName.hasPrefix("todo.") {
            let toDoID = ToDoID(rawValue: String(recordName.dropFirst(5)))
            let noteID = try toDoDataSource.todo(id: toDoID)?.noteID
            try toDoDataSource.softDelete(toDoID: toDoID, deletedAt: dateService.now())
            return noteID.map { [$0] } ?? []
        }

        if recordName.hasPrefix("attachment.") {
            let attachmentID = AttachmentID(rawValue: String(recordName.dropFirst(11)))
            let attachment = try attachmentsDataSource.attachment(id: attachmentID)
            _ = try attachmentsDataSource.softDelete(attachmentID: attachmentID, deletedAt: dateService.now())
            if let relativePath = attachment?.relativePath {
                try? fileService.deleteItem(atRelativePath: relativePath)
            }
            return attachment.map { [$0.noteID] } ?? []
        }

        if recordName.hasPrefix("snippet.") {
            let snippetID = String(recordName.dropFirst(8))
            let snippet = try attachmentsDataSource.snippet(id: snippetID)
            guard let snippet else { return [] }
            let current = try attachmentsDataSource.snippets(for: snippet.noteID)
            let survivorSet = current.filter { $0.id != snippetID }
            _ = try attachmentsDataSource.replaceSnippets(survivorSet, for: snippet.noteID)
            return [snippet.noteID]
        }

        return []
    }

    private func refreshDerivedState(for noteIDs: Set<NoteID>) async throws {
        guard !noteIDs.isEmpty else { return }

        for noteID in noteIDs {
            guard let note = try notesDataSource.note(id: noteID), !note.isDeleted else {
                try await searchIndexRepository.remove(noteID: noteID)
                continue
            }

            let labels = try labelsDataSource.labels(for: noteID)
            let attachments = try attachmentsDataSource.attachments(for: noteID)
            let snippets = try attachmentsDataSource.snippets(for: noteID)
            let toDos = try toDoDataSource.listForNote(noteID: noteID, includeDeleted: false)

            let document = SearchDocument(
                id: noteID,
                title: note.title,
                bodyPlainText: note.bodyPlainText,
                labelsText: labels.map(\.name).joined(separator: " "),
                snippetsText: snippets.compactMap { snippet in
                    [snippet.title, snippet.snippetDescription, snippet.code].compactMap { $0 }.joined(separator: " ")
                }.joined(separator: " "),
                attachmentNames: attachments.map(\.originalFileName).joined(separator: " "),
                primaryType: note.primaryType,
                snippetLanguageHint: note.snippetLanguageHint,
                updatedAt: note.updatedAt,
                isPinned: note.isPinned,
                isFavorite: note.isFavorite,
                hasTasks: !toDos.filter { !$0.isDeleted }.isEmpty,
                hasAttachments: !attachments.isEmpty,
                languagesText: snippets.map(\.language).joined(separator: " ")
            )
            try await searchIndexRepository.upsert(document)
        }
    }

    private func sortOrder(for recordType: String) -> Int {
        switch recordType {
        case SyncMapper.RecordType.note: 0
        case SyncMapper.RecordType.label: 1
        case SyncMapper.RecordType.toDo: 2
        case SyncMapper.RecordType.attachment: 3
        case SyncMapper.RecordType.snippet: 4
        case SyncMapper.RecordType.noteLabel: 5
        default: 99
        }
    }

    private var activeZoneID: CKRecordZone.ID {
        if Constants.usesCustomZone {
            return CKRecordZone.ID(zoneName: Constants.zoneName, ownerName: CKCurrentUserDefaultName)
        }
        return CKRecordZone.default().zoneID
    }

    private func ensurePrivateDatabaseScope() throws {
        guard configuration.databaseScope == .private else {
            throw SyncEngineError.invalidDatabaseScope
        }
    }

    private func ensureAccountAvailability() async throws {
        let status = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CKAccountStatus, Error>) in
            configuredContainer().accountStatus { accountStatus, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: accountStatus)
                }
            }
        }

        guard status == .available else {
            throw SyncEngineError.cloudKitAccountUnavailable
        }
    }

    private func ensureZoneExists() async throws {
        guard Constants.usesCustomZone else { return }
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [CKRecordZone(zoneID: activeZoneID)], recordZoneIDsToDelete: nil)
        operation.modifyRecordZonesResultBlock = { _ in }
        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifyRecordZonesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            configuredDatabase().add(operation)
        }
    }

    private func ensureDatabaseSubscriptionIfNeeded() async {
        guard configuration.databaseScope == .private else { return }

        let isInstalled = (try? await syncStateRepository.value(for: .databaseSubscriptionInstalled)) == "1"
        guard !isInstalled else { return }

        let subscription = CKDatabaseSubscription(subscriptionID: CloudKitPushConstants.privateDatabaseSubscriptionID)
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        do {
            try await save(subscription: subscription)
            try await syncStateRepository.setValue("1", for: .databaseSubscriptionInstalled)
        } catch {
            print("CloudKit subscription install failed: \(error)")
        }
    }

    private func modifyRecords(records: [CKRecord], deleting recordIDs: [CKRecord.ID]) async throws -> (saved: [CKRecord], deleted: [CKRecord.ID]) {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(saved: [CKRecord], deleted: [CKRecord.ID]), Error>) in
            let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: recordIDs)
            operation.savePolicy = .changedKeys
            operation.isAtomic = false
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: (records, recordIDs))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            configuredDatabase().add(operation)
        }
    }

    private func save(subscription: CKSubscription) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: [])
            operation.modifySubscriptionsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            configuredDatabase().add(operation)
        }
    }

    private func fetchRecords(ofType recordType: String, predicate: NSPredicate) async throws -> [CKRecord] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[CKRecord], Error>) in
            let query = CKQuery(recordType: recordType, predicate: predicate)
            let operation = CKQueryOperation(query: query)
            operation.zoneID = activeZoneID

            var records: [CKRecord] = []
            operation.recordMatchedBlock = { _, result in
                if case .success(let record) = result {
                    records.append(record)
                }
            }
            operation.queryResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: records)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            configuredDatabase().add(operation)
        }
    }

    private func fetchAllRecords(ofType recordType: String) async throws -> [CKRecord] {
        var records: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?

        repeat {
            let batch = try await fetchRecordBatch(ofType: recordType, cursor: cursor)
            records.append(contentsOf: batch.records)
            cursor = batch.cursor
        } while cursor != nil

        return records
    }

    private func fetchAllRecordsAllowingEmptyType(ofType recordType: String) async throws -> [CKRecord] {
        do {
            return try await fetchAllRecords(ofType: recordType)
        } catch {
            if cloudKitHTTPStatus(from: error) == 500 || (error as? CKError)?.code == .serverRejectedRequest {
                return []
            }
            throw error
        }
    }

    private func fetchRecordBatch(
        ofType recordType: String,
        cursor: CKQueryOperation.Cursor?
    ) async throws -> (records: [CKRecord], cursor: CKQueryOperation.Cursor?) {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(records: [CKRecord], cursor: CKQueryOperation.Cursor?), Error>) in
            let operation: CKQueryOperation
            if let cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
                operation = CKQueryOperation(query: query)
                operation.zoneID = activeZoneID
            }

            var records: [CKRecord] = []
            operation.recordMatchedBlock = { _, result in
                if case .success(let record) = result {
                    records.append(record)
                }
            }
            operation.queryResultBlock = { result in
                switch result {
                case .success(let nextCursor):
                    continuation.resume(returning: (records, nextCursor))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            configuredDatabase().add(operation)
        }
    }

    private func fetchZoneChanges(since token: CKServerChangeToken?) async throws -> (changed: [CKRecord], deleted: [CKRecord.ID], newToken: CKServerChangeToken?) {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(changed: [CKRecord], deleted: [CKRecord.ID], newToken: CKServerChangeToken?), Error>) in
            var changed: [CKRecord] = []
            var deleted: [CKRecord.ID] = []
            var latestToken: CKServerChangeToken?

            let options = CKFetchRecordZoneChangesOperation.ZoneOptions()
            options.previousServerChangeToken = token

            let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [activeZoneID], optionsByRecordZoneID: [activeZoneID: options])
            operation.recordWasChangedBlock = { recordID, result in
                if case .success(let record) = result {
                    changed.append(record)
                } else {
                    _ = recordID
                }
            }
            operation.recordWithIDWasDeletedBlock = { recordID, _ in
                deleted.append(recordID)
            }
            operation.recordZoneChangeTokensUpdatedBlock = { _, serverChangeToken, _ in
                latestToken = serverChangeToken
            }
            operation.recordZoneFetchCompletionBlock = { _, serverChangeToken, _, _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                latestToken = serverChangeToken ?? latestToken
            }
            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: (changed, deleted, latestToken))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            configuredDatabase().add(operation)
        }
    }

    private func reconcileNoteLabelAssignments(with remoteRecords: [CKRecord]) async throws -> Set<NoteID> {
        let remoteAssignments = remoteRecords.compactMap(syncMapper.noteLabelPayload(from:))
        let remoteByNote = Dictionary(grouping: remoteAssignments, by: \.noteID)
            .mapValues { Set($0.map(\.labelID)) }

        let localAssignments = try labelsDataSource.allNoteLabelAssignments()
        let localByNote = Dictionary(grouping: localAssignments, by: \.noteID)
            .mapValues { Set($0.map(\.labelID)) }

        let noteIDs = Set(remoteByNote.keys).union(localByNote.keys)
        for noteID in noteIDs {
            let remoteLabelIDs = remoteByNote[noteID] ?? []
            let localLabelIDs = localByNote[noteID] ?? []

            for labelID in localLabelIDs.subtracting(remoteLabelIDs) {
                try labelsDataSource.remove(labelID: labelID, from: noteID)
            }

            for labelID in remoteLabelIDs.subtracting(localLabelIDs) {
                try labelsDataSource.add(labelID: labelID, to: noteID)
            }
        }

        return noteIDs
    }

    private func configuredContainer() -> CKContainer {
        configuration.containerIdentifier.map(CKContainer.init(identifier:)) ?? CKContainer.default()
    }

    private func shouldWriteDownloadedAsset(
        existingAttachment: Attachment?,
        resolvedAttachment: Attachment
    ) -> Bool {
        guard let existingAttachment else { return true }

        if existingAttachment.relativePath != resolvedAttachment.relativePath {
            return true
        }

        if existingAttachment.checksum != nil,
           existingAttachment.checksum == resolvedAttachment.checksum,
           existingAttachment.version == resolvedAttachment.version,
           existingAttachment.updatedAt == resolvedAttachment.updatedAt,
           let existingURL = try? fileService.absoluteURL(for: existingAttachment.relativePath),
           FileManager.default.fileExists(atPath: existingURL.path) {
            return false
        }

        return true
    }

    private func performStorageCleanup(purgeCloudKitAssetCache: Bool) async throws {
        let retainedRelativePaths = try Set(
            attachmentsDataSource
                .allAttachmentsIncludingDeleted()
                .map(\.relativePath)
                .filter { !$0.isEmpty }
        )

        _ = try fileService.cleanupStorage(
            retainingAttachmentRelativePaths: retainedRelativePaths,
            maximumRetainedBackups: 2,
            purgeCloudKitAssetCache: purgeCloudKitAssetCache
        )
    }

    private func configuredDatabase() -> CKDatabase {
        configuredContainer().database(with: configuration.databaseScope)
    }

    private func cloudKitHTTPStatus(from error: Error) -> Int? {
        let nsError = error as NSError
        if let value = nsError.userInfo["CKHTTPStatus"] as? NSNumber {
            return value.intValue
        }
        return nil
    }

    private func diagnosticSummary(for error: Error, queueItem: SyncQueueItem) -> String {
        var parts = [
            "queue item \(queueItem.entityType.rawValue) \(queueItem.entityID)",
            "op=\(queueItem.operation.rawValue)"
        ]

        if let ckError = error as? CKError {
            parts.append("ck=\(ckError.code.rawValue)")
            parts.append("ckName=\(String(describing: ckError.code))")

            if let status = cloudKitHTTPStatus(from: ckError) {
                parts.append("http=\(status)")
            }

            if !ckError.localizedDescription.isEmpty {
                parts.append("message=\(ckError.localizedDescription)")
            }

            if let partial = ckError.partialErrorsByItemID, !partial.isEmpty {
                let sample = partial.prefix(3).map { key, value in
                    "\(String(describing: key)):\((value as NSError).localizedDescription)"
                }.joined(separator: "; ")
                parts.append("partial=\(sample)")
            }
        } else {
            if let status = cloudKitHTTPStatus(from: error) {
                parts.append("http=\(status)")
            }
            parts.append("message=\(error.localizedDescription)")
        }

        return parts.joined(separator: " | ")
    }

    private func publishDisabledStatus(pendingCount: Int) async {
        if pendingCount > 0 {
            await publishStatus(.offlinePending(pendingCount))
            return
        }

        if let lastSyncDate = try? await syncStateRepository.lastSuccessfulSyncDate() {
            await publishStatus(.success(lastSyncDate))
        } else {
            await publishStatus(.idle)
        }
    }

    private func publishStatus(_ status: SyncStatus) async {
        await MainActor.run {
            syncStatusStore.update(status)
        }
    }
}

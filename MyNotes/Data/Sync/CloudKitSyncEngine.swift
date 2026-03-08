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
    case cloudKitTransportNotImplemented
    case missingLocalEntity(SyncQueueItem.EntityType, String)

    var errorDescription: String? {
        switch self {
        case .cloudKitTransportNotImplemented:
            "CloudKit transport is not configured yet"
        case .missingLocalEntity(let entityType, let entityID):
            "Missing local \(entityType.rawValue) \(entityID)"
        }
    }
}

actor DefaultCloudKitSyncEngine: CloudKitSyncEngine {
    private let configuration: CloudKitSyncConfiguration
    private let syncQueue: any SyncQueue
    private let syncStateRepository: any SyncStateRepository
    private let syncMapper: SyncMapper
    private let conflictResolver: ConflictResolver
    private let notesDataSource: NotesLocalDataSource
    private let labelsDataSource: LabelsLocalDataSource
    private let attachmentsDataSource: AttachmentsLocalDataSource
    private let syncStatusStore: SyncStatusStore
    private let dateService: any DateService

    init(
        configuration: CloudKitSyncConfiguration,
        syncQueue: any SyncQueue,
        syncStateRepository: any SyncStateRepository,
        syncMapper: SyncMapper,
        conflictResolver: ConflictResolver,
        notesDataSource: NotesLocalDataSource,
        labelsDataSource: LabelsLocalDataSource,
        attachmentsDataSource: AttachmentsLocalDataSource,
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
        self.syncStatusStore = syncStatusStore
        self.dateService = dateService
    }

    func performSyncIfNeeded() async {
        let pendingCount = (try? await syncQueue.pendingCount()) ?? 0

        guard configuration.isEnabled else {
            await publishDisabledStatus(pendingCount: pendingCount)
            return
        }

        await publishStatus(.syncing)

        do {
            if pendingCount > 0 {
                try await processPendingSyncQueueCycle()
            }
            try await pullLatestChangesCycle()

            let now = dateService.now()
            try await syncStateRepository.setLastSuccessfulSyncDate(now)
            try await syncStateRepository.setValue(nil, for: .lastFailureSummary)
            await publishStatus(.success(now))
        } catch {
            try? await syncStateRepository.setValue(error.localizedDescription, for: .lastFailureSummary)
            await publishStatus(.failed(error.localizedDescription))
        }
    }

    func processPendingSyncQueue() async {
        guard configuration.isEnabled else {
            let pendingCount = (try? await syncQueue.pendingCount()) ?? 0
            await publishDisabledStatus(pendingCount: pendingCount)
            return
        }

        await publishStatus(.syncing)

        do {
            try await processPendingSyncQueueCycle()
            let now = dateService.now()
            try await syncStateRepository.setLastSuccessfulSyncDate(now)
            await publishStatus(.success(now))
        } catch {
            await publishStatus(.failed(error.localizedDescription))
        }
    }

    func pullLatestChanges() async {
        guard configuration.isEnabled else {
            let pendingCount = (try? await syncQueue.pendingCount()) ?? 0
            await publishDisabledStatus(pendingCount: pendingCount)
            return
        }

        await publishStatus(.syncing)

        do {
            try await pullLatestChangesCycle()
            let now = dateService.now()
            try await syncStateRepository.setLastSuccessfulSyncDate(now)
            await publishStatus(.success(now))
        } catch {
            await publishStatus(.failed(error.localizedDescription))
        }
    }

    private func processPendingSyncQueueCycle() async throws {
        let items = try await syncQueue.pendingItems(limit: 50)

        for item in items {
            let attemptedAt = dateService.now()
            do {
                try await syncQueue.markProcessing(itemID: item.id, attemptedAt: attemptedAt)
                try await push(queueItem: item)
                try await syncQueue.markSucceeded(itemID: item.id)
            } catch {
                try await syncQueue.markFailed(
                    itemID: item.id,
                    attemptedAt: attemptedAt,
                    errorSummary: error.localizedDescription
                )
                throw error
            }
        }
    }

    private func pullLatestChangesCycle() async throws {
        _ = conflictResolver
        _ = try await syncStateRepository.value(for: .databaseChangeToken)
        throw SyncEngineError.cloudKitTransportNotImplemented
    }

    private func push(queueItem item: SyncQueueItem) async throws {
        switch item.entityType {
        case .note:
            let noteID = NoteID(rawValue: item.entityID)
            guard let note = try notesDataSource.note(id: noteID) else {
                throw SyncEngineError.missingLocalEntity(.note, item.entityID)
            }
            try await push(records: [syncMapper.noteRecord(for: note)], deleting: [])

        case .label:
            let labelID = LabelID(rawValue: item.entityID)
            guard let label = try labelsDataSource.label(id: labelID) else {
                throw SyncEngineError.missingLocalEntity(.label, item.entityID)
            }
            try await push(records: [syncMapper.labelRecord(for: label)], deleting: [])

        case .attachment:
            let attachmentID = AttachmentID(rawValue: item.entityID)
            guard let attachment = try attachmentsDataSource.attachment(id: attachmentID) else {
                throw SyncEngineError.missingLocalEntity(.attachment, item.entityID)
            }
            try await push(records: [syncMapper.attachmentRecord(for: attachment)], deleting: [])

        case .snippet:
            guard let snippet = try attachmentsDataSource.snippet(id: item.entityID) else {
                throw SyncEngineError.missingLocalEntity(.snippet, item.entityID)
            }
            try await push(records: [syncMapper.snippetRecord(for: snippet)], deleting: [])

        case .noteLabel:
            let noteID = NoteID(rawValue: item.entityID)
            let note = try notesDataSource.note(id: noteID)
            let labels = try labelsDataSource.labels(for: noteID).map(\.id)
            let records = syncMapper.noteLabelRecords(
                noteID: noteID,
                labelIDs: labels,
                payloadVersion: note?.version ?? max(1, item.payloadVersion),
                updatedAt: note?.updatedAt ?? dateService.now()
            )

            // TODO: Also diff and delete stale NoteLabel records when remote transport is in place.
            try await push(records: records, deleting: [])
        }
    }

    private func push(records: [CKRecord], deleting recordIDs: [CKRecord.ID]) async throws {
        _ = configuredDatabase()
        _ = records
        _ = recordIDs

        // TODO: Replace with CKModifyRecordsOperation once CloudKit container/entitlements are configured.
        throw SyncEngineError.cloudKitTransportNotImplemented
    }

    private func configuredDatabase() -> CKDatabase {
        let container = configuration.containerIdentifier.map(CKContainer.init(identifier:)) ?? CKContainer.default()
        return container.database(with: configuration.databaseScope)
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

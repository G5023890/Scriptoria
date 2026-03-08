import Foundation

protocol LabelsRepository {
    func allLabels() async throws -> [Label]
    func label(id: LabelID) async throws -> Label?
    func labels(for noteID: NoteID) async throws -> [Label]
    func noteIDs(for labelID: LabelID) async throws -> [NoteID]
    func create(label: Label) async throws
    func rename(labelID: LabelID, to newName: String, updatedAt: Date) async throws
    func delete(labelID: LabelID, deletedAt: Date) async throws
    func assign(labelIDs: [LabelID], to noteID: NoteID) async throws
    func remove(labelID: LabelID, from noteID: NoteID) async throws
}

struct LocalLabelsRepository: LabelsRepository {
    let dataSource: LabelsLocalDataSource

    func allLabels() async throws -> [Label] {
        try dataSource.allLabels()
    }

    func label(id: LabelID) async throws -> Label? {
        try dataSource.label(id: id)
    }

    func labels(for noteID: NoteID) async throws -> [Label] {
        try dataSource.labels(for: noteID)
    }

    func noteIDs(for labelID: LabelID) async throws -> [NoteID] {
        try dataSource.noteIDs(for: labelID)
    }

    func create(label: Label) async throws {
        try dataSource.create(label)
    }

    func rename(labelID: LabelID, to newName: String, updatedAt: Date) async throws {
        try dataSource.rename(labelID: labelID, to: newName, updatedAt: updatedAt)
    }

    func delete(labelID: LabelID, deletedAt: Date) async throws {
        try dataSource.delete(labelID: labelID, deletedAt: deletedAt)
        // TODO: Reindex affected notes from a dedicated label mutation use case.
    }

    func assign(labelIDs: [LabelID], to noteID: NoteID) async throws {
        try dataSource.assign(labelIDs: labelIDs, to: noteID)
    }

    func remove(labelID: LabelID, from noteID: NoteID) async throws {
        try dataSource.remove(labelID: labelID, from: noteID)
    }
}

struct SyncAwareLabelsRepository: LabelsRepository {
    let base: any LabelsRepository
    let syncQueue: any SyncQueue

    func allLabels() async throws -> [Label] {
        try await base.allLabels()
    }

    func label(id: LabelID) async throws -> Label? {
        try await base.label(id: id)
    }

    func labels(for noteID: NoteID) async throws -> [Label] {
        try await base.labels(for: noteID)
    }

    func noteIDs(for labelID: LabelID) async throws -> [NoteID] {
        try await base.noteIDs(for: labelID)
    }

    func create(label: Label) async throws {
        try await base.create(label: label)
        try await enqueue(.label, entityID: label.id.rawValue, operation: .create, payloadVersion: label.version)
    }

    func rename(labelID: LabelID, to newName: String, updatedAt: Date) async throws {
        try await base.rename(labelID: labelID, to: newName, updatedAt: updatedAt)
        guard let label = try await base.label(id: labelID) else { return }
        try await enqueue(.label, entityID: labelID.rawValue, operation: .update, payloadVersion: label.version)
    }

    func delete(labelID: LabelID, deletedAt: Date) async throws {
        try await base.delete(labelID: labelID, deletedAt: deletedAt)
        if let label = try await base.label(id: labelID) {
            try await enqueue(.label, entityID: labelID.rawValue, operation: .delete, payloadVersion: label.version)
        }
    }

    func assign(labelIDs: [LabelID], to noteID: NoteID) async throws {
        try await base.assign(labelIDs: labelIDs, to: noteID)
        try await enqueue(.noteLabel, entityID: noteID.rawValue, operation: .update, payloadVersion: 1)
    }

    func remove(labelID: LabelID, from noteID: NoteID) async throws {
        try await base.remove(labelID: labelID, from: noteID)
        try await enqueue(.noteLabel, entityID: noteID.rawValue, operation: .update, payloadVersion: 1)
    }

    private func enqueue(
        _ entityType: SyncQueueItem.EntityType,
        entityID: String,
        operation: SyncQueueItem.Operation,
        payloadVersion: Int
    ) async throws {
        _ = try await syncQueue.enqueuePendingLocalChange(
            SyncEnqueueRequest(
                entityType: entityType,
                entityID: entityID,
                operation: operation,
                payloadVersion: payloadVersion
            )
        )
    }
}

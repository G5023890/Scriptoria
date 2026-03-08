import Foundation

protocol NotesRepository {
    func count() async throws -> Int
    func note(id: NoteID) async throws -> Note?
    func listNotes(query: NoteQuery) async throws -> [Note]
    func recentNotes(limit: Int) async throws -> [Note]
    func create(note: Note) async throws
    func update(note: Note) async throws
    func softDelete(noteID: NoteID, deletedAt: Date) async throws
    func restore(noteID: NoteID, restoredAt: Date) async throws
    func setPinned(_ isPinned: Bool, for noteID: NoteID, updatedAt: Date) async throws
    func setFavorite(_ isFavorite: Bool, for noteID: NoteID, updatedAt: Date) async throws
}

struct LocalNotesRepository: NotesRepository {
    let dataSource: NotesLocalDataSource

    func count() async throws -> Int {
        try dataSource.count()
    }

    func note(id: NoteID) async throws -> Note? {
        try dataSource.note(id: id)
    }

    func listNotes(query: NoteQuery) async throws -> [Note] {
        try dataSource.list(query: query)
    }

    func recentNotes(limit: Int) async throws -> [Note] {
        try dataSource.recentNotes(limit: limit)
    }

    func create(note: Note) async throws {
        try dataSource.create(note)
    }

    func update(note: Note) async throws {
        try dataSource.update(note)
    }

    func softDelete(noteID: NoteID, deletedAt: Date) async throws {
        try dataSource.softDelete(noteID: noteID, deletedAt: deletedAt)
    }

    func restore(noteID: NoteID, restoredAt: Date) async throws {
        try dataSource.restore(noteID: noteID, restoredAt: restoredAt)
    }

    func setPinned(_ isPinned: Bool, for noteID: NoteID, updatedAt: Date) async throws {
        try dataSource.setPinned(isPinned, for: noteID, updatedAt: updatedAt)
    }

    func setFavorite(_ isFavorite: Bool, for noteID: NoteID, updatedAt: Date) async throws {
        try dataSource.setFavorite(isFavorite, for: noteID, updatedAt: updatedAt)
    }
}

struct SyncAwareNotesRepository: NotesRepository {
    let base: any NotesRepository
    let syncQueue: any SyncQueue

    func count() async throws -> Int {
        try await base.count()
    }

    func note(id: NoteID) async throws -> Note? {
        try await base.note(id: id)
    }

    func listNotes(query: NoteQuery) async throws -> [Note] {
        try await base.listNotes(query: query)
    }

    func recentNotes(limit: Int) async throws -> [Note] {
        try await base.recentNotes(limit: limit)
    }

    func create(note: Note) async throws {
        try await base.create(note: note)
        try await enqueue(.note, entityID: note.id.rawValue, operation: .create, payloadVersion: note.version)
    }

    func update(note: Note) async throws {
        try await base.update(note: note)
        try await enqueue(.note, entityID: note.id.rawValue, operation: .update, payloadVersion: note.version)
    }

    func softDelete(noteID: NoteID, deletedAt: Date) async throws {
        try await base.softDelete(noteID: noteID, deletedAt: deletedAt)
        guard let note = try await base.note(id: noteID) else { return }
        try await enqueue(.note, entityID: noteID.rawValue, operation: .delete, payloadVersion: note.version)
    }

    func restore(noteID: NoteID, restoredAt: Date) async throws {
        try await base.restore(noteID: noteID, restoredAt: restoredAt)
        guard let note = try await base.note(id: noteID) else { return }
        try await enqueue(.note, entityID: noteID.rawValue, operation: .update, payloadVersion: note.version)
    }

    func setPinned(_ isPinned: Bool, for noteID: NoteID, updatedAt: Date) async throws {
        try await base.setPinned(isPinned, for: noteID, updatedAt: updatedAt)
        guard let note = try await base.note(id: noteID) else { return }
        try await enqueue(.note, entityID: noteID.rawValue, operation: .update, payloadVersion: note.version)
    }

    func setFavorite(_ isFavorite: Bool, for noteID: NoteID, updatedAt: Date) async throws {
        try await base.setFavorite(isFavorite, for: noteID, updatedAt: updatedAt)
        guard let note = try await base.note(id: noteID) else { return }
        try await enqueue(.note, entityID: noteID.rawValue, operation: .update, payloadVersion: note.version)
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

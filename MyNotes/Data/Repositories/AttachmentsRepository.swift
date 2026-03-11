import Foundation

struct SnippetMutationResult: Sendable {
    let upserted: [NoteSnippet]
    let deleted: [NoteSnippet]

    static let empty = SnippetMutationResult(upserted: [], deleted: [])
}

protocol AttachmentsRepository {
    func attachment(id: AttachmentID) async throws -> Attachment?
    func attachments(for noteID: NoteID) async throws -> [Attachment]
    func snippet(id: String) async throws -> NoteSnippet?
    func snippets(for noteID: NoteID, includeCode: Bool) async throws -> [NoteSnippet]
    func add(attachment: Attachment) async throws
    func remove(attachmentID: AttachmentID) async throws
    func replaceSnippets(_ snippets: [NoteSnippet], for noteID: NoteID) async throws -> SnippetMutationResult
}

struct LocalAttachmentsRepository: AttachmentsRepository {
    let dataSource: AttachmentsLocalDataSource
    let fileService: any FileService
    let dateService: any DateService

    func attachment(id: AttachmentID) async throws -> Attachment? {
        try dataSource.attachment(id: id)
    }

    func attachments(for noteID: NoteID) async throws -> [Attachment] {
        try dataSource.attachments(for: noteID)
    }

    func snippet(id: String) async throws -> NoteSnippet? {
        try dataSource.snippet(id: id)
    }

    func snippets(for noteID: NoteID, includeCode: Bool = true) async throws -> [NoteSnippet] {
        try dataSource.snippets(for: noteID, includeCode: includeCode)
    }

    func add(attachment: Attachment) async throws {
        try dataSource.add(attachment)
    }

    func remove(attachmentID: AttachmentID) async throws {
        guard let attachment = try dataSource.softDelete(attachmentID: attachmentID, deletedAt: dateService.now()) else {
            return
        }
        try? fileService.deleteItem(atRelativePath: attachment.relativePath)
    }

    func replaceSnippets(_ snippets: [NoteSnippet], for noteID: NoteID) async throws -> SnippetMutationResult {
        try dataSource.replaceSnippets(snippets, for: noteID)
    }
}

struct SyncAwareAttachmentsRepository: AttachmentsRepository {
    let base: any AttachmentsRepository
    let syncQueue: any SyncQueue

    func attachment(id: AttachmentID) async throws -> Attachment? {
        try await base.attachment(id: id)
    }

    func attachments(for noteID: NoteID) async throws -> [Attachment] {
        try await base.attachments(for: noteID)
    }

    func snippet(id: String) async throws -> NoteSnippet? {
        try await base.snippet(id: id)
    }

    func snippets(for noteID: NoteID, includeCode: Bool = true) async throws -> [NoteSnippet] {
        try await base.snippets(for: noteID, includeCode: includeCode)
    }

    func add(attachment: Attachment) async throws {
        try await base.add(attachment: attachment)
        try await enqueue(.attachment, entityID: attachment.id.rawValue, operation: .create, payloadVersion: attachment.version)
    }

    func remove(attachmentID: AttachmentID) async throws {
        let existingAttachment = try await base.attachment(id: attachmentID)
        try await base.remove(attachmentID: attachmentID)
        let payloadVersion = existingAttachment.map { $0.version + 1 } ?? 1
        try await enqueue(.attachment, entityID: attachmentID.rawValue, operation: .delete, payloadVersion: payloadVersion)
    }

    func replaceSnippets(_ snippets: [NoteSnippet], for noteID: NoteID) async throws -> SnippetMutationResult {
        let result = try await base.replaceSnippets(snippets, for: noteID)

        for snippet in result.upserted {
            try await enqueue(.snippet, entityID: snippet.id, operation: .update, payloadVersion: snippet.version)
        }

        for snippet in result.deleted {
            try await enqueue(.snippet, entityID: snippet.id, operation: .delete, payloadVersion: snippet.version)
        }

        return result
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

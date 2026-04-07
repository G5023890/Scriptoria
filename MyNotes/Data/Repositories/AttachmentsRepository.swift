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
    func update(attachment: Attachment) async throws -> Attachment?
    func remove(attachmentID: AttachmentID) async throws
    func setAttachmentArchived(attachmentID: AttachmentID, isArchived: Bool) async throws -> Attachment?
    func setSnippetArchived(snippetID: String, isArchived: Bool) async throws -> NoteSnippet?
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

    func update(attachment: Attachment) async throws -> Attachment? {
        try dataSource.update(attachment)
    }

    func remove(attachmentID: AttachmentID) async throws {
        guard let attachment = try dataSource.softDelete(attachmentID: attachmentID, deletedAt: dateService.now()) else {
            return
        }
        try? fileService.deleteItem(atRelativePath: attachment.relativePath)
    }

    func setAttachmentArchived(attachmentID: AttachmentID, isArchived: Bool) async throws -> Attachment? {
        try dataSource.setAttachmentArchived(
            attachmentID: attachmentID,
            isArchived: isArchived,
            updatedAt: dateService.now()
        )
    }

    func setSnippetArchived(snippetID: String, isArchived: Bool) async throws -> NoteSnippet? {
        try dataSource.setSnippetArchived(
            snippetID: snippetID,
            isArchived: isArchived,
            updatedAt: dateService.now()
        )
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

    func update(attachment: Attachment) async throws -> Attachment? {
        let existingAttachment = try await base.attachment(id: attachment.id)
        let updatedAttachment = try await base.update(attachment: attachment)

        guard existingAttachment != updatedAttachment, let updatedAttachment else {
            return updatedAttachment
        }

        try await enqueue(
            .attachment,
            entityID: attachment.id.rawValue,
            operation: .update,
            payloadVersion: updatedAttachment.version
        )
        return updatedAttachment
    }

    func remove(attachmentID: AttachmentID) async throws {
        let existingAttachment = try await base.attachment(id: attachmentID)
        try await base.remove(attachmentID: attachmentID)
        let payloadVersion = existingAttachment.map { $0.version + 1 } ?? 1
        try await enqueue(.attachment, entityID: attachmentID.rawValue, operation: .delete, payloadVersion: payloadVersion)
    }

    func setAttachmentArchived(attachmentID: AttachmentID, isArchived: Bool) async throws -> Attachment? {
        let existingAttachment = try await base.attachment(id: attachmentID)
        let updatedAttachment = try await base.setAttachmentArchived(attachmentID: attachmentID, isArchived: isArchived)

        guard existingAttachment?.isArchived != updatedAttachment?.isArchived, let updatedAttachment else {
            return updatedAttachment
        }

        try await enqueue(
            .attachment,
            entityID: attachmentID.rawValue,
            operation: .update,
            payloadVersion: updatedAttachment.version
        )
        return updatedAttachment
    }

    func setSnippetArchived(snippetID: String, isArchived: Bool) async throws -> NoteSnippet? {
        let existingSnippet = try await base.snippet(id: snippetID)
        let updatedSnippet = try await base.setSnippetArchived(snippetID: snippetID, isArchived: isArchived)

        guard existingSnippet?.isArchived != updatedSnippet?.isArchived, let updatedSnippet else {
            return updatedSnippet
        }

        try await enqueue(
            .snippet,
            entityID: snippetID,
            operation: .update,
            payloadVersion: updatedSnippet.version
        )
        return updatedSnippet
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

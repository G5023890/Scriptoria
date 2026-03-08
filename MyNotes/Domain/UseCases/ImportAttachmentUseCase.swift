import Foundation

struct ImportAttachmentUseCase {
    let attachmentsRepository: any AttachmentsRepository
    let fileService: any FileService
    let dateService: any DateService
    let indexNoteForSearchUseCase: IndexNoteForSearchUseCase

    func execute(sourceURL: URL, noteID: NoteID) async throws -> Attachment {
        let attachmentID = AttachmentID()
        let imported = try fileService.importAttachment(from: sourceURL, noteID: noteID, attachmentID: attachmentID)
        let now = dateService.now()
        let attachment = Attachment(
            id: attachmentID,
            noteID: noteID,
            fileName: imported.fileName,
            originalFileName: imported.originalFileName,
            mimeType: imported.mimeType,
            category: imported.category,
            relativePath: imported.relativePath,
            fileSize: imported.fileSize,
            checksum: imported.checksum,
            width: imported.width,
            height: imported.height,
            duration: imported.duration,
            pageCount: imported.pageCount,
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
            deletedAt: nil,
            version: 1
        )
        try await attachmentsRepository.add(attachment: attachment)
        try await indexNoteForSearchUseCase.execute(noteID: noteID)
        return attachment
    }

    func execute(sourceURLs: [URL], noteID: NoteID) async throws -> [Attachment] {
        var importedAttachments: [Attachment] = []

        for sourceURL in sourceURLs {
            importedAttachments.append(try await execute(sourceURL: sourceURL, noteID: noteID))
        }

        return importedAttachments
    }
}

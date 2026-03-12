import Foundation

struct ArchiveAttachmentUseCase {
    let attachmentsRepository: any AttachmentsRepository
    let indexNoteForSearchUseCase: IndexNoteForSearchUseCase

    func execute(attachmentID: AttachmentID) async throws -> Attachment? {
        let attachment = try await attachmentsRepository.setAttachmentArchived(
            attachmentID: attachmentID,
            isArchived: true
        )

        if let attachment {
            try await indexNoteForSearchUseCase.execute(noteID: attachment.noteID)
        }

        return attachment
    }
}

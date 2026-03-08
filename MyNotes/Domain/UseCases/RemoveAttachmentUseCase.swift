import Foundation

struct RemoveAttachmentUseCase {
    let attachmentsRepository: any AttachmentsRepository
    let indexNoteForSearchUseCase: IndexNoteForSearchUseCase

    func execute(attachment: Attachment) async throws {
        try await attachmentsRepository.remove(attachmentID: attachment.id)
        try await indexNoteForSearchUseCase.execute(noteID: attachment.noteID)
    }
}

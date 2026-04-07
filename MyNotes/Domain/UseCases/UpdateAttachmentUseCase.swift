import Foundation

struct UpdateAttachmentUseCase {
    let attachmentsRepository: any AttachmentsRepository
    let indexNoteForSearchUseCase: IndexNoteForSearchUseCase
    let dateService: any DateService

    func execute(attachment: Attachment, description: String) async throws -> Attachment? {
        let normalizedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty

        guard attachment.description != normalizedDescription else {
            return attachment
        }

        var updatedAttachment = attachment
        updatedAttachment.description = normalizedDescription
        updatedAttachment.updatedAt = dateService.now()
        updatedAttachment.version += 1

        guard let savedAttachment = try await attachmentsRepository.update(attachment: updatedAttachment) else {
            return nil
        }

        try await indexNoteForSearchUseCase.execute(noteID: attachment.noteID)
        return savedAttachment
    }
}

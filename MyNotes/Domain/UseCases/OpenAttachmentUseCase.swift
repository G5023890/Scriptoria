import Foundation

struct OpenAttachmentUseCase {
    let quickLookService: any QuickLookService

    func execute(for attachment: Attachment) throws {
        try quickLookService.openInSystem(for: attachment)
    }
}

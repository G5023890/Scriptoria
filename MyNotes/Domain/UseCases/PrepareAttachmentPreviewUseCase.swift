import Foundation

struct PrepareAttachmentPreviewUseCase {
    let quickLookService: any QuickLookService

    func execute(for attachment: Attachment) throws -> URL? {
        try quickLookService.previewURL(for: attachment)
    }
}

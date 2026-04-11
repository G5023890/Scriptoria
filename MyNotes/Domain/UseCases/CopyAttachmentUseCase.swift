import Foundation

struct CopyAttachmentUseCase {
    let clipboardService: any ClipboardService

    func execute(fileURL: URL) {
        clipboardService.copy(fileURL)
    }
}

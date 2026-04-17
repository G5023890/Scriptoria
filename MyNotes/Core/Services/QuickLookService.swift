import Foundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

protocol QuickLookService {
    func previewURL(for attachment: Attachment) throws -> URL?
    func openInSystem(for attachment: Attachment) throws
}

struct DefaultQuickLookService: QuickLookService {
    let fileService: any FileService

    func previewURL(for attachment: Attachment) throws -> URL? {
        try fileService.absoluteURL(for: attachment.relativePath)
    }

    func openInSystem(for attachment: Attachment) throws {
        let url = try fileService.absoluteURL(for: attachment.relativePath)
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }
}

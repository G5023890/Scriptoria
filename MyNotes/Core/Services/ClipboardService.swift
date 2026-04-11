import AppKit
import Foundation

protocol ClipboardService {
    func copy(_ string: String)
    func copy(_ fileURL: URL)
}

struct SystemClipboardService: ClipboardService {
    func copy(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    func copy(_ fileURL: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([fileURL as NSURL])
    }
}

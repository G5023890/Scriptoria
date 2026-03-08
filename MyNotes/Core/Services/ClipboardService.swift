import AppKit
import Foundation

protocol ClipboardService {
    func copy(_ string: String)
}

struct SystemClipboardService: ClipboardService {
    func copy(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}

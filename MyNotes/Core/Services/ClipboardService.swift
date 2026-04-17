import Foundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

protocol ClipboardService {
    func copy(_ string: String)
    func copy(_ fileURL: URL)
}

struct SystemClipboardService: ClipboardService {
    func copy(_ string: String) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        #else
        UIPasteboard.general.string = string
        #endif
    }

    func copy(_ fileURL: URL) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([fileURL as NSURL])
        #else
        UIPasteboard.general.url = fileURL
        #endif
    }
}

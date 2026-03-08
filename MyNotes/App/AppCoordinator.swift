import Observation
import SwiftUI

enum AppSceneID: String {
    case mainWindow = "main-window"
    case quickCapture = "quick-capture"
}

@MainActor
@Observable
final class AppCoordinator {
    var selectedNoteID: NoteID?
    var requestedSidebarSelection: SidebarSelection?
    var currentSidebarSelection: SidebarSelection = .collection(.allNotes)
    var emptyTrashRequestID: UUID?

    func openMainWindow(using openWindow: OpenWindowAction) {
        openWindow(id: AppSceneID.mainWindow.rawValue)
    }

    func openQuickCaptureWindow(using openWindow: OpenWindowAction) {
        openWindow(id: AppSceneID.quickCapture.rawValue)
    }

    func revealNoteFromQuickCapture(_ note: Note, using openWindow: OpenWindowAction? = nil) {
        requestedSidebarSelection = .collection(.allNotes)
        selectedNoteID = note.id

        if let openWindow {
            openMainWindow(using: openWindow)
        }
    }

    func requestEmptyTrash() {
        emptyTrashRequestID = UUID()
    }

    func consumeRequestedSidebarSelection() -> SidebarSelection? {
        defer { requestedSidebarSelection = nil }
        return requestedSidebarSelection
    }

    func consumeEmptyTrashRequest() -> UUID? {
        defer { emptyTrashRequestID = nil }
        return emptyTrashRequestID
    }

    func triggerSync(using environment: AppEnvironment) {
        Task {
            await environment.performSyncIfNeeded()
        }
    }
}

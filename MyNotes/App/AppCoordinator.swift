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
    var selectedToDoID: ToDoID?
    var requestedSidebarSelection: SidebarSelection?
    var currentSidebarSelection: SidebarSelection = .collection(.allNotes)
    var emptyTrashRequestID: UUID?
    var newNoteRequestID: UUID?

    func openMainWindow(using openWindow: OpenWindowAction) {
        openWindow(id: AppSceneID.mainWindow.rawValue)
    }

    func openQuickCaptureWindow(using openWindow: OpenWindowAction) {
        openWindow(id: AppSceneID.quickCapture.rawValue)
    }

    func requestNewNote(using openWindow: OpenWindowAction? = nil) {
        newNoteRequestID = UUID()
        selectedToDoID = nil

        if let openWindow {
            openMainWindow(using: openWindow)
        }
    }

    func revealNote(_ note: Note, using openWindow: OpenWindowAction? = nil) {
        requestedSidebarSelection = .collection(.allNotes)
        selectedNoteID = note.id
        selectedToDoID = nil

        if let openWindow {
            openMainWindow(using: openWindow)
        }
    }

    func revealToDo(noteID: NoteID, toDoID: ToDoID, using openWindow: OpenWindowAction? = nil) {
        selectedNoteID = noteID
        selectedToDoID = toDoID

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

    func consumeNewNoteRequest() -> UUID? {
        defer { newNoteRequestID = nil }
        return newNoteRequestID
    }

    func triggerSync(using environment: AppEnvironment) {
        Task {
            await environment.performSyncIfNeeded()
        }
    }
}

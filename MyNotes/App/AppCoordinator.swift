import Observation
import SwiftUI

enum AppSceneID: String {
    case mainWindow = "main-window"
    case quickCapture = "quick-capture"
}

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case search
    case browse
    case tasks

    var id: String { rawValue }
}

@MainActor
@Observable
final class AppCoordinator {
    var selectedNoteID: NoteID?
    var selectedToDoID: ToDoID?
    var activeTab: AppTab = .home
    var requestedSidebarSelection: SidebarSelection?
    var currentSidebarSelection: SidebarSelection = .collection(.allNotes)
    var emptyTrashRequestID: UUID?
    var newNoteRequestID: UUID?

    func requestNewNote() {
        newNoteRequestID = UUID()
        selectedToDoID = nil
        activeTab = .home
    }

    func revealNote(_ note: Note) {
        requestedSidebarSelection = .collection(.allNotes)
        selectedNoteID = note.id
        selectedToDoID = nil
        activeTab = .home
    }

    func revealToDo(noteID: NoteID, toDoID: ToDoID) {
        selectedNoteID = noteID
        selectedToDoID = toDoID
        activeTab = .tasks
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

#if os(macOS)
extension AppCoordinator {
    func openMainWindow(using openWindow: OpenWindowAction) {
        openWindow(id: AppSceneID.mainWindow.rawValue)
    }

    func openQuickCaptureWindow(using openWindow: OpenWindowAction) {
        openWindow(id: AppSceneID.quickCapture.rawValue)
    }

    func requestNewNote(using openWindow: OpenWindowAction) {
        requestNewNote()
        openMainWindow(using: openWindow)
    }

    func revealNote(_ note: Note, using openWindow: OpenWindowAction) {
        revealNote(note)
        openMainWindow(using: openWindow)
    }

    func revealToDo(noteID: NoteID, toDoID: ToDoID, using openWindow: OpenWindowAction) {
        revealToDo(noteID: noteID, toDoID: toDoID)
        openMainWindow(using: openWindow)
    }
}
#endif

import Foundation

struct EmptyTrashUseCase {
    let notesRepository: any NotesRepository
    let databaseManager: DatabaseManager
    let fileService: any FileService
    let searchIndexRepository: any SearchIndexRepository
    let refreshToDoNotificationsUseCase: RefreshToDoNotificationsUseCase

    func execute() async throws {
        let trashedNotes = try await notesRepository.listNotes(
            query: NoteQuery(
                collection: .trash,
                includeDeleted: true
            )
        )

        guard !trashedNotes.isEmpty else { return }

        for note in trashedNotes {
            try? fileService.deleteItem(atRelativePath: "attachments/note_\(note.id.rawValue)")
        }

        try databaseManager.transaction { db in
            for note in trashedNotes {
                try db.execute(
                    statement: "DELETE FROM note_labels WHERE note_id = ?;",
                    bindings: [.text(note.id.rawValue)]
                )
                try db.execute(
                    statement: "DELETE FROM attachments WHERE note_id = ?;",
                    bindings: [.text(note.id.rawValue)]
                )
                try db.execute(
                    statement: "DELETE FROM snippets WHERE note_id = ?;",
                    bindings: [.text(note.id.rawValue)]
                )
                try db.execute(
                    statement: "DELETE FROM todos WHERE note_id = ?;",
                    bindings: [.text(note.id.rawValue)]
                )
                try db.execute(
                    statement: "DELETE FROM notes_fts WHERE note_id = ?;",
                    bindings: [.text(note.id.rawValue)]
                )
                try db.execute(
                    statement: "DELETE FROM notes WHERE id = ?;",
                    bindings: [.text(note.id.rawValue)]
                )
            }
        }

        for note in trashedNotes {
            try await searchIndexRepository.remove(noteID: note.id)
        }

        await refreshToDoNotificationsUseCase.execute(promptIfNeeded: false)
    }
}

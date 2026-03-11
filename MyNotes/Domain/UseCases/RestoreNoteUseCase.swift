import Foundation

struct RestoreNoteUseCase {
    let notesRepository: any NotesRepository
    let dateService: any DateService
    let indexNoteForSearchUseCase: IndexNoteForSearchUseCase
    let refreshToDoNotificationsUseCase: RefreshToDoNotificationsUseCase

    func execute(noteID: NoteID) async throws {
        try await notesRepository.restore(noteID: noteID, restoredAt: dateService.now())
        try await indexNoteForSearchUseCase.execute(noteID: noteID)
        await refreshToDoNotificationsUseCase.execute(promptIfNeeded: false)
    }
}

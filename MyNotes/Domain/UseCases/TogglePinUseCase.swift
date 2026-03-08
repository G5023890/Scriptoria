import Foundation

struct TogglePinUseCase {
    let notesRepository: any NotesRepository
    let dateService: any DateService
    let indexNoteForSearchUseCase: IndexNoteForSearchUseCase

    func execute(noteID: NoteID, isPinned: Bool) async throws {
        try await notesRepository.setPinned(isPinned, for: noteID, updatedAt: dateService.now())
        try await indexNoteForSearchUseCase.execute(noteID: noteID)
    }
}

import Foundation

struct ToggleFavoriteUseCase {
    let notesRepository: any NotesRepository
    let dateService: any DateService
    let indexNoteForSearchUseCase: IndexNoteForSearchUseCase

    func execute(noteID: NoteID, isFavorite: Bool) async throws {
        try await notesRepository.setFavorite(isFavorite, for: noteID, updatedAt: dateService.now())
        try await indexNoteForSearchUseCase.execute(noteID: noteID)
    }
}

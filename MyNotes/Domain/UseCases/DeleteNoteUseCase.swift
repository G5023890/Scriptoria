import Foundation

struct DeleteNoteUseCase {
    let notesRepository: any NotesRepository
    let searchIndexRepository: any SearchIndexRepository
    let dateService: any DateService

    func execute(noteID: NoteID) async throws {
        try await notesRepository.softDelete(noteID: noteID, deletedAt: dateService.now())
        try await searchIndexRepository.remove(noteID: noteID)
    }
}

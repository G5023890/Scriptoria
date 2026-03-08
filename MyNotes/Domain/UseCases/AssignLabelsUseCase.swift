import Foundation

struct AssignLabelsUseCase {
    let labelsRepository: any LabelsRepository
    let indexNoteForSearchUseCase: IndexNoteForSearchUseCase

    func execute(noteID: NoteID, labelIDs: [LabelID]) async throws {
        try await labelsRepository.assign(labelIDs: labelIDs, to: noteID)
        try await indexNoteForSearchUseCase.execute(noteID: noteID)
    }
}

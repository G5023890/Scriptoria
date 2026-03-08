import Foundation

struct QuickCaptureUseCase {
    let createNoteUseCase: CreateNoteUseCase
    let assignLabelsUseCase: AssignLabelsUseCase
    let indexNoteForSearchUseCase: IndexNoteForSearchUseCase

    func execute(
        title: String,
        bodyMarkdown: String,
        labelIDs: [LabelID],
        isPinned: Bool,
        isFavorite: Bool
    ) async throws -> Note {
        let note = try await createNoteUseCase.execute(
            title: title,
            bodyMarkdown: bodyMarkdown,
            isPinned: isPinned,
            isFavorite: isFavorite
        )
        try await assignLabelsUseCase.execute(noteID: note.id, labelIDs: labelIDs)
        try await indexNoteForSearchUseCase.execute(noteID: note.id)
        return note
    }
}

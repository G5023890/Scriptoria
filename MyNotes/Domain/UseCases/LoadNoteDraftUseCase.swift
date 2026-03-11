import Foundation

struct LoadNoteDraftUseCase {
    let getNoteSnapshotUseCase: GetNoteSnapshotUseCase

    func execute(noteID: NoteID) async throws -> NoteDraft? {
        guard let snapshot = try await getNoteSnapshotUseCase.execute(noteID: noteID) else {
            return nil
        }
        return NoteDraft(
            note: snapshot.note,
            labels: snapshot.labels,
            todos: snapshot.todos,
            attachments: snapshot.attachments,
            snippets: snapshot.snippets
        )
    }
}

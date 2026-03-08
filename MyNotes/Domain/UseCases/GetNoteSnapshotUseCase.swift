import Foundation

struct GetNoteSnapshotUseCase {
    let notesRepository: any NotesRepository
    let labelsRepository: any LabelsRepository
    let attachmentsRepository: any AttachmentsRepository

    func execute(noteID: NoteID) async throws -> NoteSnapshot? {
        guard let note = try await notesRepository.note(id: noteID) else {
            return nil
        }

        let labels = try await labelsRepository.labels(for: noteID)
        let attachments = try await attachmentsRepository.attachments(for: noteID)
        let snippets = try await attachmentsRepository.snippets(for: noteID)
        return NoteSnapshot(note: note, labels: labels, attachments: attachments, snippets: snippets)
    }
}

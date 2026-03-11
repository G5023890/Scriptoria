import Foundation

struct NoteListItem: Sendable {
    let note: Note
    let labels: [Label]
    let attachmentCount: Int
    let snippetCount: Int
}

struct ListNoteSnapshotsUseCase {
    let notesRepository: any NotesRepository
    let labelsRepository: any LabelsRepository
    let attachmentsRepository: any AttachmentsRepository
    let toDoRepository: any ToDoRepository

    func executeListItems(collection: SmartCollection, labelID: LabelID?) async throws -> [NoteListItem] {
        let notes = try await notesRepository.listNotes(
            query: NoteQuery(
                collection: collection,
                labelID: labelID,
                includeDeleted: collection == .trash
            )
        )
        var items: [NoteListItem] = []
        items.reserveCapacity(notes.count)

        for note in notes {
            do {
                let labels = try await labelsRepository.labels(for: note.id)
                let attachmentCount = try await attachmentsRepository.attachments(for: note.id).count
                let snippetCount = try await attachmentsRepository.snippets(for: note.id, includeCode: false).count

                items.append(
                    NoteListItem(
                        note: note,
                        labels: labels,
                        attachmentCount: attachmentCount,
                        snippetCount: snippetCount
                    )
                )
            } catch {
                // Skip a single malformed/heavy note instead of blanking the whole list.
                continue
            }
        }

        return items
    }

    func execute(collection: SmartCollection, labelID: LabelID?) async throws -> [NoteSnapshot] {
        var snapshots: [NoteSnapshot] = []
        let notes = try await notesRepository.listNotes(
            query: NoteQuery(
                collection: collection,
                labelID: labelID,
                includeDeleted: collection == .trash
            )
        )
        snapshots.reserveCapacity(notes.count)

        for note in notes {
            do {
                let labels = try await labelsRepository.labels(for: note.id)
                let attachments = try await attachmentsRepository.attachments(for: note.id)
                let snippets = try await attachmentsRepository.snippets(for: note.id, includeCode: false)

                snapshots.append(
                    NoteSnapshot(
                        note: note,
                        labels: labels,
                        todos: try await toDoRepository.listForNote(noteID: note.id, includeDeleted: true),
                        attachments: attachments,
                        snippets: snippets
                    )
                )
            } catch {
                continue
            }
        }

        return snapshots
    }
}

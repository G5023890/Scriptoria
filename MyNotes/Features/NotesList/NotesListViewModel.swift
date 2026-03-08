import Foundation
import Observation

@MainActor
@Observable
final class NotesListViewModel {
    struct EmptyState: Sendable {
        let title: String
        let message: String
    }

    var rows: [NoteRowModel] = []
    var isLoading = false
    var selectionTitle = SmartCollection.allNotes.title
    var emptyState = EmptyState(
        title: "No Notes",
        message: "Create your first note to start building your library."
    )

    private let listNoteSnapshotsUseCase: ListNoteSnapshotsUseCase
    private let getNoteSnapshotUseCase: GetNoteSnapshotUseCase
    private var currentSelection: SidebarSelection = .collection(.allNotes)

    init(
        listNoteSnapshotsUseCase: ListNoteSnapshotsUseCase,
        getNoteSnapshotUseCase: GetNoteSnapshotUseCase
    ) {
        self.listNoteSnapshotsUseCase = listNoteSnapshotsUseCase
        self.getNoteSnapshotUseCase = getNoteSnapshotUseCase
    }

    func reload(selection: SidebarSelection, labelName: String? = nil) async {
        currentSelection = selection
        applyPresentation(selection: selection, labelName: labelName)
        isLoading = true
        defer { isLoading = false }

        do {
            let items = try await listNoteSnapshotsUseCase.executeListItems(
                collection: baseCollection(for: selection),
                labelID: selectedLabelID(for: selection)
            )
            rows = items.map { item in
                NoteRowModel(
                    note: item.note,
                    labels: item.labels,
                    attachmentCount: item.attachmentCount,
                    snippetCount: item.snippetCount
                )
            }
            sortRows()
        } catch {
            rows = []
        }
    }

    @discardableResult
    func refreshNote(noteID: NoteID, labelName: String? = nil) async -> Bool {
        applyPresentation(selection: currentSelection, labelName: labelName)

        do {
            guard let snapshot = try await getNoteSnapshotUseCase.execute(noteID: noteID) else {
                rows.removeAll { $0.id == noteID }
                return false
            }

            guard matchesCurrentSelection(snapshot: snapshot) else {
                rows.removeAll { $0.id == noteID }
                return false
            }

            let row = NoteRowModel(snapshot: snapshot)
            if let index = rows.firstIndex(where: { $0.id == noteID }) {
                rows[index] = row
            } else {
                rows.append(row)
            }
            sortRows()
            return true
        } catch {
            return rows.contains(where: { $0.id == noteID })
        }
    }

    func contains(noteID: NoteID?) -> Bool {
        guard let noteID else { return false }
        return rows.contains { $0.id == noteID }
    }

    private func baseCollection(for selection: SidebarSelection) -> SmartCollection {
        switch selection {
        case .collection(let collection):
            collection
        case .label:
            .allNotes
        }
    }

    private func selectedLabelID(for selection: SidebarSelection) -> LabelID? {
        switch selection {
        case .collection:
            nil
        case .label(let labelID):
            labelID
        }
    }

    private func applyPresentation(selection: SidebarSelection, labelName: String?) {
        switch selection {
        case .collection(let collection):
            selectionTitle = collection.title
            emptyState = emptyState(for: collection)
        case .label:
            let title = labelName ?? "Label"
            selectionTitle = title
            emptyState = EmptyState(
                title: "No Notes in \(title)",
                message: "Notes tagged with \(title) will appear here."
            )
        }
    }

    private func emptyState(for collection: SmartCollection) -> EmptyState {
        switch collection {
        case .allNotes:
            EmptyState(
                title: "No Notes Yet",
                message: "Use Quick Capture to create your first note."
            )
        case .favorites:
            EmptyState(
                title: "No Favorite Notes",
                message: "Star important notes to keep them here."
            )
        case .pinned:
            EmptyState(
                title: "Nothing Pinned",
                message: "Pin notes you want to keep at the top."
            )
        case .recent:
            EmptyState(
                title: "No Recent Notes",
                message: "Notes updated in the last week will appear here."
            )
        case .attachments:
            EmptyState(
                title: "No Attachments Yet",
                message: "Notes with imported files will appear in this collection."
            )
        case .snippets:
            EmptyState(
                title: "No Snippets Yet",
                message: "Code blocks detected in notes will surface here."
            )
        case .trash:
            EmptyState(
                title: "Trash Is Empty",
                message: "Deleted notes will stay here until restored or removed permanently."
            )
        }
    }

    private func matchesCurrentSelection(snapshot: NoteSnapshot) -> Bool {
        switch currentSelection {
        case .collection(let collection):
            matches(snapshot: snapshot, collection: collection)
        case .label(let labelID):
            !snapshot.note.isDeleted &&
            !snapshot.note.isArchived &&
            snapshot.labels.contains(where: { $0.id == labelID })
        }
    }

    private func matches(snapshot: NoteSnapshot, collection: SmartCollection) -> Bool {
        let note = snapshot.note

        switch collection {
        case .allNotes:
            return !note.isDeleted && !note.isArchived
        case .favorites:
            return !note.isDeleted && !note.isArchived && note.isFavorite
        case .pinned:
            return !note.isDeleted && !note.isArchived && note.isPinned
        case .recent:
            let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            return !note.isDeleted && !note.isArchived && note.updatedAt >= sevenDaysAgo
        case .attachments:
            return !note.isDeleted && !note.isArchived && snapshot.hasAttachments
        case .snippets:
            return !note.isDeleted && !note.isArchived && snapshot.hasSnippets
        case .trash:
            return note.isDeleted
        }
    }

    private func sortRows() {
        rows.sort { lhs, rhs in
            let left = lhs.note
            let right = rhs.note

            if left.isPinned != right.isPinned {
                return left.isPinned && !right.isPinned
            }

            if left.sortDate != right.sortDate {
                return left.sortDate > right.sortDate
            }

            return left.updatedAt > right.updatedAt
        }
    }
}

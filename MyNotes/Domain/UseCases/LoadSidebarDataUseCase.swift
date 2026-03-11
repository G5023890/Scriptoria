import Foundation

struct LoadSidebarDataUseCase {
    let notesRepository: any NotesRepository
    let labelsRepository: any LabelsRepository
    let attachmentsRepository: any AttachmentsRepository
    let toDoRepository: any ToDoRepository

    func execute() async throws -> SidebarData {
        let labels = try await labelsRepository.allLabels()

        let collections = SmartCollection.allCases
        var counts: [SmartCollection: Int] = [:]
        for collection in collections {
            if collection == .tasks {
                counts[collection] = try await toDoRepository.countForSidebar()
            } else {
                let notes = try await notesRepository.listNotes(
                    query: NoteQuery(
                        collection: collection,
                        includeDeleted: collection == .trash
                    )
                )
                counts[collection] = notes.count
            }
        }

        var labelSummaries: [SidebarLabelSummary] = []
        for label in labels {
            let noteCount = try await labelsRepository.noteIDs(for: label.id).count
            labelSummaries.append(SidebarLabelSummary(label: label, noteCount: noteCount))
        }

        return SidebarData(collectionCounts: counts, labels: labelSummaries)
    }
}

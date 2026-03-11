import Foundation
import Observation

struct ToDoSectionModel: Identifiable, Sendable {
    let group: ToDoTaskListItem.Group
    let rows: [GlobalToDoRowModel]

    var id: ToDoTaskListItem.Group { group }
}

@MainActor
@Observable
final class ToDosListViewModel {
    var sections: [ToDoSectionModel] = []
    var isLoading = false
    var emptyTitle = "No Tasks Yet"
    var emptyMessage = "Tasks created inside notes will appear here."

    private let listAllToDosUseCase: ListAllToDosUseCase

    init(listAllToDosUseCase: ListAllToDosUseCase) {
        self.listAllToDosUseCase = listAllToDosUseCase
    }

    func row(for toDoID: ToDoID?) -> GlobalToDoRowModel? {
        guard let toDoID else { return nil }
        for section in sections {
            if let row = section.rows.first(where: { $0.id == toDoID }) {
                return row
            }
        }
        return nil
    }

    func reload() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let rows = try await listAllToDosUseCase.execute()
                .map(ToDoPresentationBuilder.makeGlobalRow)

            sections = ToDoTaskListItem.Group.allCases.compactMap { group in
                let groupRows = rows.filter { $0.group == group }
                guard !groupRows.isEmpty else { return nil }
                return ToDoSectionModel(group: group, rows: groupRows)
            }
        } catch {
            sections = []
        }
    }
}

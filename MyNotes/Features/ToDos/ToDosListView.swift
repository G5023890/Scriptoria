import Observation
import SwiftUI

struct ToDosListView: View {
    @Bindable var viewModel: ToDosListViewModel
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        let selection = Binding<ToDoID?>(
            get: { coordinator.selectedToDoID },
            set: { coordinator.selectedToDoID = $0 }
        )

        return List(selection: selection) {
            ForEach(viewModel.sections) { section in
                tasksSection(section)
            }
        }
        .navigationTitle("Tasks")
        .overlay {
            if viewModel.sections.isEmpty && !viewModel.isLoading {
                ContentUnavailableView {
                    SwiftUI.Label(viewModel.emptyTitle, systemImage: AppIcons.tasks)
                } description: {
                    Text(viewModel.emptyMessage)
                }
            }
        }
        .onChange(of: coordinator.selectedToDoID) { _, toDoID in
            guard let row = viewModel.row(for: toDoID) else { return }
            coordinator.revealToDo(noteID: row.todo.noteID, toDoID: row.id)
        }
    }

    @ViewBuilder
    private func tasksSection(_ section: ToDoSectionModel) -> some View {
        Section(section.group.title) {
            ForEach(section.rows) { row in
                ToDoListRowView(row: row)
                    .tag(row.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        coordinator.revealToDo(noteID: row.todo.noteID, toDoID: row.id)
                    }
            }
        }
    }
}

private struct ToDoListRowView: View {
    let row: GlobalToDoRowModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack(alignment: .center, spacing: AppSpacing.small) {
                Image(systemName: row.todo.isCompleted ? AppIcons.taskComplete : AppIcons.taskIncomplete)
                    .foregroundStyle(row.todo.isCompleted ? .green : .secondary)
                Text(row.title)
                    .font(AppTypography.bodySemibold)
                    .strikethrough(row.todo.isCompleted)
                    .lineLimit(1)
                Spacer()
                if let dueText = row.dueText {
                    Text(dueText)
                        .font(AppTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(row.noteTitle)
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

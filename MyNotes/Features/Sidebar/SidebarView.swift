import Observation
import SwiftUI

struct SidebarView: View {
    @Bindable var viewModel: SidebarViewModel

    var body: some View {
        List(selection: $viewModel.selection) {
            Section("Browse") {
                ForEach(SmartCollection.allCases) { collection in
                    HStack(spacing: AppSpacing.small) {
                        SwiftUI.Label(collection.title, systemImage: collection.systemImage)
                        Spacer()
                        InfoBadge(text: "\(viewModel.noteCount(for: collection))")
                    }
                    .tag(SidebarSelection.collection(collection))
                    .contextMenu {
                        if collection == .trash {
                            Button("Empty Trash") {
                                viewModel.requestEmptyTrash()
                            }
                        }
                    }
                }
            }

            Divider()

            Section("Labels") {
                ForEach(viewModel.labels) { item in
                    HStack(spacing: AppSpacing.small) {
                        Image(systemName: item.label.iconName ?? "tag")
                            .foregroundStyle(.secondary)
                        Text(item.label.name)
                        Spacer()
                        InfoBadge(text: "\(item.noteCount)")
                    }
                    .tag(SidebarSelection.label(item.label.id))
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("MyNotes")
    }
}

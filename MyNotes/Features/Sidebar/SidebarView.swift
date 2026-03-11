import Observation
import SwiftUI

struct SidebarView: View {
    @Bindable var viewModel: SidebarViewModel

    private var renameAlertPresented: Binding<Bool> {
        Binding(
            get: { viewModel.labelBeingRenamed != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.cancelRename()
                }
            }
        )
    }

    private var errorAlertPresented: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage?.isEmpty == false },
            set: { isPresented in
                if !isPresented {
                    viewModel.clearError()
                }
            }
        )
    }

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
                    .contextMenu {
                        Button("Rename") {
                            viewModel.beginRename(for: item)
                        }
                        .disabled(item.label.isSystem)

                        Button("Delete", role: .destructive) {
                            Task {
                                await viewModel.deleteLabel(item)
                            }
                        }
                        .disabled(item.label.isSystem)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("MyNotes")
        .sheet(item: $viewModel.labelBeingRenamed) { _ in
            renameLabelSheet
        }
        .alert("Label Error", isPresented: errorAlertPresented) {
            Button("OK", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }

    @ViewBuilder
    private var renameLabelSheet: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Rename Label")
                .font(.headline)

            TextField("Label Name", text: $viewModel.draftLabelName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel") {
                    viewModel.cancelRename()
                }
                Button("Save") {
                    Task {
                        await viewModel.saveRenamedLabel()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(AppSpacing.large)
        .frame(minWidth: 360)
    }
}

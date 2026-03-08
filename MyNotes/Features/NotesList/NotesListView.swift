import Observation
import SwiftUI

struct NotesListView: View {
    @Environment(\.openWindow) private var openWindow

    @Bindable var viewModel: NotesListViewModel
    @Bindable var searchViewModel: SearchViewModel
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            searchFilterBar
            content
        }
        .navigationTitle(searchViewModel.isSearching ? "Search" : viewModel.selectionTitle)
        .searchable(
            text: Binding(
                get: { searchViewModel.queryText },
                set: searchViewModel.updateQuery
            ),
            placement: .toolbar,
            prompt: "Search notes or use filters like kind:snippet"
        )
    }

    private var searchFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.small) {
                ForEach(SearchViewModel.QuickFilter.allCases) { filter in
                    Button {
                        searchViewModel.toggleQuickFilter(filter)
                    } label: {
                        Text(filter.title)
                            .font(AppTypography.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                searchViewModel.isQuickFilterActive(filter)
                                    ? AppColors.chipBackground
                                    : Color.secondary.opacity(0.08),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.small)
        }
    }

    @ViewBuilder
    private var content: some View {
        if searchViewModel.isSearching {
            SearchResultsView(viewModel: searchViewModel, coordinator: coordinator)
        } else {
            List(selection: $coordinator.selectedNoteID) {
                ForEach(viewModel.rows) { row in
                    NoteListRowView(row: row)
                        .tag(row.id)
                }
            }
            .overlay {
                if viewModel.rows.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView {
                        SwiftUI.Label(viewModel.emptyState.title, systemImage: "doc.text")
                    } description: {
                        Text(viewModel.emptyState.message)
                    } actions: {
                        Button("Quick Capture") {
                            coordinator.openQuickCaptureWindow(using: openWindow)
                        }
                    }
                }
            }
        }
    }
}

private struct NoteListRowView: View {
    let row: NoteRowModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack {
                Text(row.title)
                    .font(AppTypography.bodySemibold)
                    .lineLimit(1)
                Spacer()
                if row.isPinned {
                    Image(systemName: AppIcons.pin)
                }
                if row.isFavorite {
                    Image(systemName: AppIcons.favorite)
                }
            }

            Text(row.previewText)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: AppSpacing.small) {
                ForEach(row.visibleLabels) { label in
                    LabelChipView(label: label)
                }
                if row.extraLabelCount > 0 {
                    InfoBadge(text: "+\(row.extraLabelCount)")
                }
                if row.hasAttachments {
                    HStack(spacing: 4) {
                        Image(systemName: AppIcons.attachment)
                        Text("\(row.attachmentCount)")
                    }
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
                }
                if row.hasCodeSnippets {
                    HStack(spacing: 4) {
                        Image(systemName: AppIcons.code)
                        Text("\(row.snippetCount)")
                    }
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Text(row.updatedDisplayText)
                    .font(AppTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

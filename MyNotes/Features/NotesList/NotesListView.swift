import Observation
import SwiftUI

struct NotesListView: View {
    @Bindable var viewModel: NotesListViewModel
    @Bindable var searchViewModel: SearchViewModel
    @Bindable var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                        Image(systemName: filter.symbolName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(
                                searchViewModel.isQuickFilterActive(filter) ? Color.accentColor : .secondary
                            )
                            .frame(width: 36, height: 36)
                            .background(
                                searchViewModel.isQuickFilterActive(filter)
                                    ? AppColors.chipBackground
                                    : Color.secondary.opacity(0.08),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .help(filter.token)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
            .padding(.horizontal, AppSpacing.small)
            .padding(.top, 14)
            .padding(.bottom, 2)
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
                        Button("New Note") {
                            coordinator.requestNewNote()
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

import Observation
import SwiftUI

struct NotesListView: View {
    @Bindable var viewModel: NotesListViewModel
    @Bindable var searchViewModel: SearchViewModel
    @Bindable var coordinator: AppCoordinator
    @Binding var isBottomSearchPresented: Bool

    #if os(iOS)
    @FocusState private var isSearchFieldFocused: Bool
    #endif

    var body: some View {
        Group {
            #if os(iOS)
            content
                .safeAreaInset(edge: .top, spacing: 0) {
                    headerBarInset
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if isBottomSearchPresented {
                        bottomSearchBar
                    }
                }
            #else
            VStack(alignment: .leading, spacing: 0) {
                headerBar
                content
            }
            #endif
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: isBottomSearchPresented) { _, isPresented in
            if isPresented {
                Task { @MainActor in
                    isSearchFieldFocused = true
                }
            } else {
                isSearchFieldFocused = false
                if searchViewModel.isSearching {
                    searchViewModel.updateQuery("")
                }
            }
        }
        #endif
    }

    private var headerBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.small) {
                collectionIconButton(
                    title: SmartCollection.allNotes.title,
                    systemImage: SmartCollection.allNotes.systemImage,
                    isActive: coordinator.currentSidebarSelection == .collection(.allNotes)
                ) {
                    searchViewModel.updateQuery("")
                    coordinator.requestedSidebarSelection = .collection(.allNotes)
                }

                ForEach(SearchViewModel.QuickFilter.allCases) { filter in
                    Button {
                        isBottomSearchPresented = true
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
                    .accessibilityLabel(Text(filter.token))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, AppSpacing.small)
            .padding(.top, 2)
            .padding(.bottom, 6)
        }
    }

    #if os(iOS)
    private var headerBarInset: some View {
        headerBar
            .background(.ultraThinMaterial)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AppColors.panelBorder)
                    .frame(height: 1)
            }
    }

    private var bottomSearchBar: some View {
        HStack(spacing: AppSpacing.small) {
            HStack(spacing: AppSpacing.xSmall) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField(
                    "Search notes or use filters like kind:snippet",
                    text: Binding(
                        get: { searchViewModel.queryText },
                        set: searchViewModel.updateQuery
                    )
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isSearchFieldFocused)

                if !searchViewModel.queryText.isEmpty {
                    Button {
                        searchViewModel.updateQuery("")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear Search")
                }
            }
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemBackground), in: Capsule())

            Button("Done") {
                isBottomSearchPresented = false
            }
            .font(.system(size: 15, weight: .semibold))
        }
        .padding(.horizontal, AppSpacing.medium)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColors.panelBorder)
                .frame(height: 1)
        }
    }
    #endif

    private func collectionIconButton(
        title: String,
        systemImage: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
                .frame(width: 36, height: 36)
                .background(
                    isActive ? AppColors.chipBackground : Color.secondary.opacity(0.08),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(Text(title))
    }

    @ViewBuilder
    private var content: some View {
        if searchViewModel.isSearching {
            SearchResultsView(viewModel: searchViewModel, coordinator: coordinator)
        } else {
            notesList
        }
    }

    @ViewBuilder
    private var notesList: some View {
        #if os(iOS)
        List {
            ForEach(viewModel.rows) { row in
                NavigationLink(value: row.id) {
                    NoteListRowView(row: row)
                }
            }
        }
        .contentMargins(.top, AppSpacing.small, for: .scrollContent)
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
        #else
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
        #endif
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
                if row.hasOpenToDos {
                    HStack(spacing: 4) {
                        Image(systemName: AppIcons.tasks)
                        Text("\(row.openToDoCount)")
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

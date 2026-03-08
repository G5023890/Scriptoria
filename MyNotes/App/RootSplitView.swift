import Observation
import SwiftUI

@MainActor
struct RootSplitView: View {
    @Environment(\.openWindow) private var openWindow

    @Bindable var coordinator: AppCoordinator
    let environment: AppEnvironment

    @State private var sidebarViewModel: SidebarViewModel
    @State private var notesListViewModel: NotesListViewModel
    @State private var noteDetailViewModel: NoteDetailViewModel
    @State private var searchViewModel: SearchViewModel

    init(coordinator: AppCoordinator, environment: AppEnvironment) {
        self.coordinator = coordinator
        self.environment = environment
        _sidebarViewModel = State(
            initialValue: environment.makeSidebarViewModel {
                coordinator.requestEmptyTrash()
            }
        )
        _notesListViewModel = State(initialValue: environment.makeNotesListViewModel())
        _noteDetailViewModel = State(initialValue: environment.makeNoteDetailViewModel())
        _searchViewModel = State(initialValue: environment.makeSearchViewModel())
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: sidebarViewModel)
        } content: {
            NotesListView(
                viewModel: notesListViewModel,
                searchViewModel: searchViewModel,
                coordinator: coordinator
            )
        } detail: {
            NoteDetailView(
                viewModel: noteDetailViewModel,
                environment: environment,
                coordinator: coordinator,
                onNoteChanged: handleNoteChanged
            )
        }
        .toolbar(content: {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    coordinator.openQuickCaptureWindow(using: openWindow)
                } label: {
                    SwiftUI.Label("Quick Capture", systemImage: "plus.circle")
                }
            }
        })
        .task {
            await environment.bootstrapSampleDataIfNeeded()
            await environment.performSyncIfNeeded()
            await reloadSidebar()
            await reloadList()
        }
        .task(id: sidebarViewModel.selection) {
            coordinator.currentSidebarSelection = sidebarViewModel.selection
            await reloadList()
        }
        .task(id: searchViewModel.queryText) {
            if !searchViewModel.isSearching && !notesListViewModel.contains(noteID: coordinator.selectedNoteID) {
                coordinator.selectedNoteID = nil
            }
        }
        .task(id: coordinator.selectedNoteID) {
            await noteDetailViewModel.load(noteID: coordinator.selectedNoteID)
            noteDetailViewModel.mode = .read
        }
        .task(id: coordinator.requestedSidebarSelection) {
            guard let requestedSelection = coordinator.consumeRequestedSidebarSelection() else { return }
            let revealedNoteID = coordinator.selectedNoteID
            searchViewModel.updateQuery("")
            sidebarViewModel.selection = requestedSelection
            coordinator.currentSidebarSelection = requestedSelection
            await reloadSidebar()
            await notesListViewModel.reload(
                selection: sidebarViewModel.selection,
                labelName: currentLabelName()
            )

            if let revealedNoteID {
                coordinator.selectedNoteID = revealedNoteID
                _ = await notesListViewModel.refreshNote(
                    noteID: revealedNoteID,
                    labelName: currentLabelName()
                )
                await noteDetailViewModel.load(noteID: revealedNoteID)
                noteDetailViewModel.mode = .edit
            }
        }
        .task(id: coordinator.emptyTrashRequestID) {
            guard coordinator.consumeEmptyTrashRequest() != nil else { return }

            do {
                try await environment.emptyTrashUseCase.execute()
                if coordinator.currentSidebarSelection == .collection(.trash) {
                    coordinator.selectedNoteID = nil
                }
                await reloadSidebar()
                await reloadList()
            } catch {
                noteDetailViewModel.errorMessage = "Empty trash failed: \(error.localizedDescription)"
            }
        }
    }

    private func reloadSidebar() async {
        await sidebarViewModel.reload()
    }

    private func reloadList() async {
        await notesListViewModel.reload(
            selection: sidebarViewModel.selection,
            labelName: currentLabelName()
        )

        if !notesListViewModel.contains(noteID: coordinator.selectedNoteID) {
            coordinator.selectedNoteID = nil
        }
    }

    private func currentLabelName() -> String? {
        switch sidebarViewModel.selection {
        case .collection:
            nil
        case .label(let labelID):
            sidebarViewModel.labelName(for: labelID)
        }
    }

    private func handleNoteChanged(noteID: NoteID) async {
        await reloadSidebar()
        let stillVisible = await notesListViewModel.refreshNote(
            noteID: noteID,
            labelName: currentLabelName()
        )

        if searchViewModel.isSearching {
            await searchViewModel.refresh()
        }

        if !stillVisible && !searchViewModel.isSearching && coordinator.selectedNoteID == noteID {
            coordinator.selectedNoteID = nil
        }

        await noteDetailViewModel.load(
            noteID: coordinator.selectedNoteID,
            preserveMode: coordinator.selectedNoteID == noteID
        )
    }

}

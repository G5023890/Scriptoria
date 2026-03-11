import Observation
import SwiftUI

@MainActor
struct RootSplitView: View {
    @Bindable var coordinator: AppCoordinator
    let environment: AppEnvironment

    @State private var sidebarViewModel: SidebarViewModel
    @State private var notesListViewModel: NotesListViewModel
    @State private var toDosListViewModel: ToDosListViewModel
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
        _toDosListViewModel = State(initialValue: environment.makeToDosListViewModel())
        _noteDetailViewModel = State(initialValue: environment.makeNoteDetailViewModel())
        _searchViewModel = State(initialValue: environment.makeSearchViewModel())
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: sidebarViewModel)
        } content: {
            if sidebarViewModel.selection == .collection(.tasks) {
                ToDosListView(
                    viewModel: toDosListViewModel,
                    coordinator: coordinator
                )
            } else {
                NotesListView(
                    viewModel: notesListViewModel,
                    searchViewModel: searchViewModel,
                    coordinator: coordinator
                )
            }
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
                    coordinator.requestNewNote()
                } label: {
                    SwiftUI.Label("New Note", systemImage: "plus.circle")
                }
            }
        })
        .task {
            environment.configureToDoNotificationRouting(
                onOpenToDo: { noteID, toDoID in
                    coordinator.revealToDo(noteID: noteID, toDoID: toDoID)
                },
                onSnoozeToDo: { toDoID, preset in
                    await environment.snoozeToDoFromNotification(toDoID: toDoID, preset: preset)
                    await reloadSidebar()
                    await reloadList()
                    await noteDetailViewModel.load(
                        noteID: coordinator.selectedNoteID,
                        preserveMode: true
                    )
                },
                onCompleteToDo: { toDoID in
                    await environment.completeToDoFromNotification(toDoID: toDoID)
                    await reloadSidebar()
                    await reloadList()
                    await noteDetailViewModel.load(
                        noteID: coordinator.selectedNoteID,
                        preserveMode: true
                    )
                }
            )
            await environment.bootstrapSampleDataIfNeeded()
            await environment.refreshToDoNotifications()
            await environment.performSyncIfNeeded()
            await reloadSidebar()
            await reloadList()
        }
        .task(id: sidebarViewModel.selection) {
            coordinator.currentSidebarSelection = sidebarViewModel.selection
            await reloadList()
        }
        .task(id: sidebarViewModel.labelsMutationID) {
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
        .task(id: coordinator.newNoteRequestID) {
            guard coordinator.consumeNewNoteRequest() != nil else { return }
            await createNewNoteInline()
        }
    }

    private func reloadSidebar() async {
        await sidebarViewModel.reload()
    }

    private func reloadList() async {
        if sidebarViewModel.selection == .collection(.tasks) {
            await toDosListViewModel.reload()
        } else {
            coordinator.selectedToDoID = nil
            await notesListViewModel.reload(
                selection: sidebarViewModel.selection,
                labelName: currentLabelName()
            )

            if !notesListViewModel.contains(noteID: coordinator.selectedNoteID) {
                coordinator.selectedNoteID = nil
            }
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
        await toDosListViewModel.reload()
        let stillVisible: Bool
        if sidebarViewModel.selection == .collection(.tasks) {
            stillVisible = true
        } else {
            stillVisible = await notesListViewModel.refreshNote(
                noteID: noteID,
                labelName: currentLabelName()
            )
        }

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

    private func createNewNoteInline() async {
        do {
            let note = try await environment.createNoteUseCase.execute(
                title: "",
                bodyMarkdown: ""
            )
            coordinator.revealNote(note)
        } catch {
            noteDetailViewModel.errorMessage = "New note creation failed: \(error.localizedDescription)"
        }
    }

}

import Observation
import SwiftUI

@MainActor
struct RootSplitView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var coordinator: AppCoordinator
    let environment: AppEnvironment

    @State private var sidebarViewModel: SidebarViewModel
    @State private var notesListViewModel: NotesListViewModel
    @State private var toDosListViewModel: ToDosListViewModel
    @State private var noteDetailViewModel: NoteDetailViewModel
    @State private var searchViewModel: SearchViewModel
    @State private var isShowingExportSelection = false

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
                    coordinator: coordinator,
                    isBottomSearchPresented: .constant(false)
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
            await environment.proAccessStore.refresh()
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
        .onReceive(NotificationCenter.default.publisher(for: .scriptoriaDidApplyRemoteSync)) { _ in
            Task {
                await reloadSidebar()
                await reloadList()
                await noteDetailViewModel.load(
                    noteID: coordinator.selectedNoteID,
                    preserveMode: true
                )
            }
        }
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: .scriptoriaRequestExportSelection)) { _ in
            isShowingExportSelection = true
        }
        .sheet(isPresented: $isShowingExportSelection) {
            ExportNotesSelectionSheet(environment: environment)
        }
        #endif
        .onChange(of: scenePhase) {
            switch scenePhase {
            case .active:
                AppRuntime.shared.startActiveSyncPollingIfNeeded(trigger: .active)
                Task {
                    await environment.performSyncIfNeeded()
                }
            case .inactive:
                #if os(macOS)
                AppRuntime.shared.startActiveSyncPollingIfNeeded(trigger: .active)
                #else
                AppRuntime.shared.stopActiveSyncPolling()
                #endif
            case .background:
                AppRuntime.shared.stopActiveSyncPolling()
            @unknown default:
                AppRuntime.shared.stopActiveSyncPolling()
            }
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

#if os(macOS)
@MainActor
private struct ExportNotesSelectionSheet: View {
    let environment: AppEnvironment

    @Environment(\.dismiss) private var dismiss
    @State private var snapshots: [NoteSnapshot] = []
    @State private var selectedIDs: Set<NoteID> = []
    @State private var isExporting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Select All", isOn: Binding(
                        get: { !snapshots.isEmpty && selectedIDs.count == snapshots.count },
                        set: { selectedIDs = $0 ? Set(snapshots.map(\.id)) : [] }
                    ))
                }

                Section("Notes") {
                    ForEach(snapshots) { snapshot in
                        Toggle(snapshot.note.displayTitle, isOn: Binding(
                            get: { selectedIDs.contains(snapshot.id) },
                            set: { isSelected in
                                if isSelected {
                                    selectedIDs.insert(snapshot.id)
                                } else {
                                    selectedIDs.remove(snapshot.id)
                                }
                            }
                        ))
                        .lineLimit(1)
                    }
                }
            }
            .overlay {
                if snapshots.isEmpty {
                    ContentUnavailableView("No Notes", systemImage: "note.text")
                }
            }
            .navigationTitle("Export Notes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export") {
                        Task { await exportSelectedNotes() }
                    }
                    .disabled(selectedIDs.isEmpty || isExporting)
                }
            }
            .task {
                do {
                    snapshots = try await environment.listNoteSnapshotsUseCase.execute(
                        collection: .allNotes,
                        labelID: nil
                    )
                    selectedIDs = Set(snapshots.map(\.id))
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            .alert("Export Failed", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .frame(minWidth: 420, minHeight: 460)
    }

    private func exportSelectedNotes() async {
        isExporting = true
        defer { isExporting = false }
        do {
            let result = try await environment.exportNotes(noteIDs: selectedIDs)
            guard AppRuntime.shared.saveDataArchive(result.archiveURL) else { return }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
#endif

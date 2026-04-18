import Combine
import SwiftUI

@MainActor
struct IPhoneRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var coordinator: AppCoordinator
    let environment: AppEnvironment

    @State private var sidebarViewModel: SidebarViewModel
    @State private var notesListViewModel: NotesListViewModel
    @State private var toDosListViewModel: ToDosListViewModel
    @State private var searchViewModel: SearchViewModel
    @State private var quickCaptureViewModel: QuickCaptureViewModel
    @State private var homePath: [NoteID] = []
    @State private var taskPath: [TaskDetailRoute] = []
    @State private var isShowingQuickCapture = false
    @State private var isBottomSearchPresented = false

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
        _searchViewModel = State(initialValue: environment.makeSearchViewModel())
        _quickCaptureViewModel = State(initialValue: environment.makeQuickCaptureViewModel())
    }

    var body: some View {
        TabView(selection: $coordinator.activeTab) {
            homeTab
                .tabItem {
                    SwiftUI.Label("Home", systemImage: "house")
                }
                .tag(AppTab.home)

            Color.clear
                .tabItem {
                    SwiftUI.Label("Search", systemImage: "magnifyingglass")
                }
                .tag(AppTab.search)

            browseTab
                .tabItem {
                    SwiftUI.Label("Browse", systemImage: "sidebar.left")
                }
                .tag(AppTab.browse)

            tasksTab
                .tabItem {
                    SwiftUI.Label("Tasks", systemImage: "checklist")
                }
                .tag(AppTab.tasks)
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                isShowingQuickCapture = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 52, height: 52)
                    .foregroundStyle(.white)
                    .background(Color.accentColor, in: Circle())
                    .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
            }
            .padding(.trailing, 18)
            .padding(.bottom, 24)
            .accessibilityLabel("Quick Capture")
        }
        .sheet(isPresented: $isShowingQuickCapture) {
            QuickCaptureView(
                viewModel: quickCaptureViewModel,
                onCaptured: { note in
                    isShowingQuickCapture = false
                    coordinator.revealNote(note)
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .task {
            environment.configureToDoNotificationRouting(
                onOpenToDo: { noteID, toDoID in
                    coordinator.revealToDo(noteID: noteID, toDoID: toDoID)
                },
                onSnoozeToDo: { toDoID, preset in
                    await environment.snoozeToDoFromNotification(toDoID: toDoID, preset: preset)
                    await reloadSidebar()
                    await reloadLists()
                },
                onCompleteToDo: { toDoID in
                    await environment.completeToDoFromNotification(toDoID: toDoID)
                    await reloadSidebar()
                    await reloadLists()
                }
            )

            await environment.bootstrapSampleDataIfNeeded()
            await environment.refreshToDoNotifications()
            await environment.performSyncIfNeeded()
            await reloadSidebar()
            await reloadLists()
            syncNavigationState()
        }
        .task(id: sidebarViewModel.selection) {
            coordinator.currentSidebarSelection = sidebarViewModel.selection
            await reloadNotesList()
            syncNavigationState()
        }
        .task(id: sidebarViewModel.labelsMutationID) {
            coordinator.currentSidebarSelection = sidebarViewModel.selection
            await reloadNotesList()
        }
        .task(id: searchViewModel.queryText) {
            if !searchViewModel.isSearching && !notesListViewModel.contains(noteID: coordinator.selectedNoteID) {
                coordinator.selectedNoteID = nil
                homePath.removeAll()
            }
        }
        .task(id: coordinator.requestedSidebarSelection) {
            guard let requestedSelection = coordinator.consumeRequestedSidebarSelection() else { return }
            searchViewModel.updateQuery("")
            sidebarViewModel.selection = requestedSelection
            coordinator.currentSidebarSelection = requestedSelection
            coordinator.activeTab = .home
            coordinator.selectedToDoID = nil
            await reloadSidebar()
            await reloadNotesList()
        }
        .task(id: coordinator.emptyTrashRequestID) {
            guard coordinator.consumeEmptyTrashRequest() != nil else { return }

            do {
                try await environment.emptyTrashUseCase.execute()
                if coordinator.currentSidebarSelection == .collection(.trash) {
                    coordinator.selectedNoteID = nil
                    homePath.removeAll()
                }
                await reloadSidebar()
                await reloadLists()
            } catch {
                print("Empty trash failed: \(error)")
            }
        }
        .task(id: coordinator.newNoteRequestID) {
            guard coordinator.consumeNewNoteRequest() != nil else { return }
            await createNewNoteInline()
        }
        .task(id: navigationSyncSignature) {
            syncNavigationState()
        }
        .onChange(of: coordinator.activeTab) { _, newValue in
            switch newValue {
            case .search:
                isBottomSearchPresented = true
                coordinator.activeTab = .home
            case .home:
                break
            case .browse, .tasks:
                isBottomSearchPresented = false
                searchViewModel.updateQuery("")
            }
        }
        .onChange(of: scenePhase) {
            switch scenePhase {
            case .active:
                environment.syncStatusStore.markDebugTrigger(.active)
#if !os(macOS)
                AppRuntime.shared.startActiveSyncPollingIfNeeded(trigger: .active)
#endif

                Task {
                    await environment.performSyncIfNeeded()
                    await reloadSidebar()
                    await reloadLists()
                    syncNavigationState()
                }
            case .inactive, .background:
#if !os(macOS)
                AppRuntime.shared.stopActiveSyncPolling()
#endif
            @unknown default:
                break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .scriptoriaDidApplyRemoteSync)) { _ in
            Task {
                await reloadSidebar()
                await reloadLists()
                syncNavigationState()
            }
        }
    }

    private var navigationSyncSignature: String {
        [
            coordinator.activeTab.rawValue,
            coordinator.selectedNoteID?.rawValue ?? "none",
            coordinator.selectedToDoID?.rawValue ?? "none"
        ].joined(separator: "::")
    }

    private var homeTab: some View {
        NavigationStack(path: $homePath) {
            NotesListView(
                viewModel: notesListViewModel,
                searchViewModel: searchViewModel,
                coordinator: coordinator,
                isBottomSearchPresented: $isBottomSearchPresented
            )
            .navigationDestination(for: NoteID.self) { noteID in
                NoteDetailScreen(
                    coordinator: coordinator,
                    environment: environment,
                    noteID: noteID,
                    focusedToDoID: nil,
                    onNoteChanged: handleNoteChanged
                )
            }
        }
    }

    private var browseTab: some View {
        NavigationStack {
            SidebarView(viewModel: sidebarViewModel, showsTasks: false, title: "Browse")
                .navigationTitle("Browse")
                .onChange(of: sidebarViewModel.selection) { _, _ in
                    guard coordinator.activeTab == .browse else { return }
                    searchViewModel.updateQuery("")
                    coordinator.activeTab = .home
                    coordinator.selectedNoteID = nil
                    coordinator.selectedToDoID = nil
                    homePath.removeAll()
                }
        }
    }

    private var tasksTab: some View {
        NavigationStack(path: $taskPath) {
            ToDosListView(viewModel: toDosListViewModel, coordinator: coordinator)
                .navigationDestination(for: TaskDetailRoute.self) { route in
                    NoteDetailScreen(
                        coordinator: coordinator,
                        environment: environment,
                        noteID: route.noteID,
                        focusedToDoID: route.toDoID,
                        onNoteChanged: handleNoteChanged
                    )
                }
        }
    }

    private func reloadSidebar() async {
        await sidebarViewModel.reload()
    }

    private func reloadNotesList() async {
        await notesListViewModel.reload(
            selection: sidebarViewModel.selection,
            labelName: currentLabelName()
        )
    }

    private func reloadToDosList() async {
        await toDosListViewModel.reload()
    }

    private func reloadLists() async {
        await reloadNotesList()
        await reloadToDosList()
    }

    private func currentLabelName() -> String? {
        switch sidebarViewModel.selection {
        case .collection:
            nil
        case .label(let labelID):
            sidebarViewModel.labelName(for: labelID)
        }
    }

    private func syncNavigationState() {
        switch coordinator.activeTab {
        case .home, .search:
            if let noteID = coordinator.selectedNoteID {
                let desiredPath = [noteID]
                if homePath != desiredPath {
                    homePath = desiredPath
                }
            } else if !homePath.isEmpty {
                homePath.removeAll()
            }

            if coordinator.selectedToDoID != nil {
                coordinator.selectedToDoID = nil
            }

        case .tasks:
            if let noteID = coordinator.selectedNoteID, let toDoID = coordinator.selectedToDoID {
                let desiredPath = [TaskDetailRoute(noteID: noteID, toDoID: toDoID)]
                if taskPath != desiredPath {
                    taskPath = desiredPath
                }
            } else if !taskPath.isEmpty {
                taskPath.removeAll()
            }

        case .browse:
            break
        }
    }

    private func handleNoteChanged(noteID: NoteID) async {
        await reloadSidebar()
        await reloadLists()

        if searchViewModel.isSearching {
            await searchViewModel.refresh()
        }

        if !searchViewModel.isSearching && coordinator.selectedNoteID == noteID && !notesListViewModel.contains(noteID: noteID) {
            coordinator.selectedNoteID = nil
            homePath.removeAll()
        }
    }

    private func createNewNoteInline() async {
        do {
            let note = try await environment.createNoteUseCase.execute(
                title: "",
                bodyMarkdown: ""
            )
            coordinator.revealNote(note)
        } catch {
            print("New note creation failed: \(error)")
        }
    }
}

import SwiftUI

#if os(iOS)
import UIKit
#endif

@MainActor
struct NoteDetailScreen: View {
    @Bindable var coordinator: AppCoordinator
    let environment: AppEnvironment
    let noteID: NoteID
    let focusedToDoID: ToDoID?
    let onNoteChanged: @MainActor (NoteID) async -> Void

    @State private var viewModel: NoteDetailViewModel

    init(
        coordinator: AppCoordinator,
        environment: AppEnvironment,
        noteID: NoteID,
        focusedToDoID: ToDoID?,
        onNoteChanged: @escaping @MainActor (NoteID) async -> Void
    ) {
        self.coordinator = coordinator
        self.environment = environment
        self.noteID = noteID
        self.focusedToDoID = focusedToDoID
        self.onNoteChanged = onNoteChanged
        _viewModel = State(initialValue: environment.makeNoteDetailViewModel())
    }

    var body: some View {
        NoteDetailView(
            viewModel: viewModel,
            environment: environment,
            coordinator: coordinator,
            onNoteChanged: onNoteChanged
        )
        .task(id: noteID) {
            coordinator.selectedNoteID = noteID
            coordinator.selectedToDoID = focusedToDoID
            await viewModel.load(noteID: noteID)
        }
        #if os(iOS)
        .navigationBarBackButtonHidden(true)
        .background(InteractivePopGestureEnabler())
        #endif
        .onDisappear {
            if coordinator.selectedNoteID == noteID {
                coordinator.selectedNoteID = nil
                coordinator.selectedToDoID = nil
            }
        }
    }
}

#if os(iOS)
private struct InteractivePopGestureEnabler: UIViewControllerRepresentable {
    final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            enableInteractivePopGesture()
        }

        func enableInteractivePopGesture() {
            guard let navigationController,
                  let gesture = navigationController.interactivePopGestureRecognizer else { return }

            gesture.isEnabled = true
            gesture.delegate = nil
        }
    }

    func makeUIViewController(context: Context) -> UIViewController {
        Controller()
    }

    func updateUIViewController(_ viewController: UIViewController, context: Context) {
        guard let controller = viewController as? Controller else { return }
        DispatchQueue.main.async {
            controller.enableInteractivePopGesture()
        }
    }
}
#endif

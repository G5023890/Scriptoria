import SwiftUI

struct QuickCaptureWindowScene: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    @Bindable var coordinator: AppCoordinator
    let environment: AppEnvironment
    @State private var viewModel: QuickCaptureViewModel

    init(coordinator: AppCoordinator, environment: AppEnvironment) {
        self.coordinator = coordinator
        self.environment = environment
        _viewModel = State(initialValue: environment.makeQuickCaptureViewModel())
    }

    var body: some View {
        QuickCaptureView(
            viewModel: viewModel,
            onCaptured: { note in
                coordinator.revealNoteFromQuickCapture(note, using: openWindow)
                dismiss()
            }
        )
        .frame(minWidth: 560, minHeight: 560)
    }
}

#if os(macOS)
import AppKit
import Observation
import SwiftUI

struct MyNotesMenuBarExtra: View {
    @Environment(\.openWindow) private var openWindow

    @Bindable var coordinator: AppCoordinator
    let environment: AppEnvironment
    @Bindable var syncStatusStore: SyncStatusStore

    init(coordinator: AppCoordinator, environment: AppEnvironment) {
        self.coordinator = coordinator
        self.environment = environment
        self.syncStatusStore = environment.syncStatusStore
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Button("Open MyNotes") {
                coordinator.openMainWindow(using: openWindow)
            }

            Button("New Note") {
                coordinator.requestNewNote(using: openWindow)
            }

            Button("Quick Capture") {
                coordinator.openQuickCaptureWindow(using: openWindow)
            }

            Divider()

            Text("Sync")
                .font(AppTypography.caption)
                .foregroundStyle(.secondary)

            Text(syncStatusStore.status.summary)
                .font(AppTypography.section)

            Button("Sync Now") {
                coordinator.triggerSync(using: environment)
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(AppSpacing.medium)
        .frame(minWidth: 220)
    }
}
#endif

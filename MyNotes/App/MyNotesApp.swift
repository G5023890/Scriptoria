import SwiftUI

@main
struct MyNotesApp: App {
    @State private var coordinator = AppCoordinator()
    private let environment = AppEnvironment.bootstrap()

    var body: some Scene {
        WindowGroup(id: AppSceneID.mainWindow.rawValue) {
            RootSplitView(coordinator: coordinator, environment: environment)
                .frame(minWidth: 1180, minHeight: 760)
        }
        .windowStyle(.automatic)

        Window("Quick Capture", id: AppSceneID.quickCapture.rawValue) {
            QuickCaptureWindowScene(coordinator: coordinator, environment: environment)
        }
        .defaultSize(width: 520, height: 460)
        .windowResizability(.contentSize)

        MenuBarExtra {
            MyNotesMenuBarExtra(coordinator: coordinator, environment: environment)
        } label: {
            Image(systemName: "text.pad.header.badge.plus")
        }
        .commands {
            CommandMenu("Notes") {
                Button("Empty Trash") {
                    coordinator.requestEmptyTrash()
                }
                .keyboardShortcut(.delete, modifiers: [.shift, .command])
                .disabled(coordinator.currentSidebarSelection != .collection(.trash))
            }
        }
    }
}

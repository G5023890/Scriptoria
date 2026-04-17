import SwiftUI

#if os(macOS)
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

        .commands {
            CommandMenu("Notes") {
                Button("New Note") {
                    coordinator.requestNewNote()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Empty Trash") {
                    coordinator.requestEmptyTrash()
                }
                .keyboardShortcut(.delete, modifiers: [.shift, .command])
                .disabled(coordinator.currentSidebarSelection != .collection(.trash))
            }
        }
    }
}
#else
@main
struct MyNotesApp: App {
    @State private var coordinator = AppCoordinator()
    private let environment = AppEnvironment.bootstrap()

    var body: some Scene {
        WindowGroup {
            IPhoneRootView(coordinator: coordinator, environment: environment)
        }
    }
}
#endif

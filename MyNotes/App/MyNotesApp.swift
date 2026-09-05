import CloudKit
import Foundation
import SwiftUI
#if os(macOS)
import UniformTypeIdentifiers
#endif
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum CloudKitPushConstants {
    static let privateDatabaseSubscriptionID = "scriptoria.private-database-changes"
}

extension Notification.Name {
    static let scriptoriaDidApplyRemoteSync = Notification.Name("scriptoria.didApplyRemoteSync")
    static let scriptoriaRequestExportSelection = Notification.Name("scriptoria.requestExportSelection")
}

@MainActor
final class AppRuntime {
    static let shared = AppRuntime()

    var environment: AppEnvironment?
    private var activePollingTimer: Timer?

    private init() {}

    func startActiveSyncPollingIfNeeded(trigger: SyncDebugTrigger = .active) {
        guard activePollingTimer == nil else { return }
        log("starting active sync polling")
        environment?.syncStatusStore.isForegroundPollingActive = true
        environment?.syncStatusStore.markDebugTrigger(trigger)

        activePollingTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            guard let self, let environment = self.environment else { return }
            guard self.shouldRunActivePolling else { return }

            self.log("active polling tick")
            environment.syncStatusStore.markDebugTrigger(.timer)
            Task { @MainActor in
                await environment.performSyncIfNeeded()
                self.log("active polling sync finished")
            }
        }
        RunLoop.main.add(activePollingTimer!, forMode: .common)
    }

    func stopActiveSyncPolling() {
        log("stopping active sync polling")
        activePollingTimer?.invalidate()
        activePollingTimer = nil
        environment?.syncStatusStore.isForegroundPollingActive = false
        environment?.syncStatusStore.markDebugTrigger(.stopped)
    }

    private var shouldRunActivePolling: Bool {
#if os(macOS)
        true
#else
        UIApplication.shared.applicationState == .active
#endif
    }

    func log(_ message: String) {
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date())
        NSLog("[ScriptoriaSync][%@] %@", timestamp, message)
    }

#if os(macOS)
    @MainActor
    func importDataArchive() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.folder]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url, let environment else { return }

        Task { @MainActor in
            do {
                let result = try await environment.importNotes(from: url)
                NotificationCenter.default.post(name: .scriptoriaDidApplyRemoteSync, object: nil)
                showTransferAlert(
                    title: "Import Complete",
                    message: "Imported \(result.importedNotes) notes and \(result.importedAttachments) attachments. \(result.skippedNotes) newer local notes were kept."
                )
            } catch {
                showTransferAlert(title: "Import Failed", message: error.localizedDescription)
            }
        }
    }

    @MainActor
    func exportDataArchive(noteIDs: Set<NoteID>? = nil) {
        guard let environment else { return }
        Task { @MainActor in
            do {
                let result = try await environment.exportNotes(noteIDs: noteIDs)
                guard saveDataArchive(result.archiveURL) else { return }
                showTransferAlert(
                    title: "Export Complete",
                    message: "Saved \(result.noteCount) notes and \(result.attachmentCount) attachments."
                )
            } catch {
                showTransferAlert(title: "Export Failed", message: error.localizedDescription)
            }
        }
    }

    @MainActor
    func saveDataArchive(_ archiveURL: URL) -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        guard panel.runModal() == .OK, let selectedDirectory = panel.url else { return false }
        let scopedAccess = selectedDirectory.startAccessingSecurityScopedResource()
        defer {
            if scopedAccess { selectedDirectory.stopAccessingSecurityScopedResource() }
        }
        do {
            let manager = FileManager.default
            let destination = selectedDirectory.appendingPathComponent(archiveURL.lastPathComponent, isDirectory: true)
            if manager.fileExists(atPath: destination.path) {
                try manager.removeItem(at: destination)
            }
            try manager.copyItem(at: archiveURL, to: destination)
            return true
        } catch {
            showTransferAlert(title: "Export Failed", message: error.localizedDescription)
            return false
        }
    }

    @MainActor
    private func showTransferAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
#endif
}

#if os(macOS)
@main
struct MyNotesApp: App {
    @State private var coordinator = AppCoordinator()
    private let environment: AppEnvironment

    init() {
        let environment = AppEnvironment.bootstrap()
        self.environment = environment
        AppRuntime.shared.environment = environment
    }

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
            CommandGroup(replacing: .newItem) {
                Button("Import Data...") {
                    AppRuntime.shared.importDataArchive()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Menu("Export") {
                    Button("All Notes and Attachments...") {
                        AppRuntime.shared.exportDataArchive()
                    }
                    Button("Selected Note...") {
                        NotificationCenter.default.post(name: .scriptoriaRequestExportSelection, object: nil)
                    }
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }

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
@MainActor
final class IOSAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        AppRuntime.shared.log("applicationDidBecomeActive")
        AppRuntime.shared.startActiveSyncPollingIfNeeded(trigger: .active)

        Task { @MainActor in
            if let environment = AppRuntime.shared.environment {
                environment.syncStatusStore.markDebugTrigger(.active)
                AppRuntime.shared.log("running immediate active sync")
                await environment.performSyncIfNeeded()
                AppRuntime.shared.log("immediate active sync finished")
            }
        }
    }

    func applicationWillResignActive(_ application: UIApplication) {
        AppRuntime.shared.log("applicationWillResignActive")
        AppRuntime.shared.stopActiveSyncPolling()
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard
            let notification = CKNotification(fromRemoteNotificationDictionary: userInfo),
            notification.subscriptionID == CloudKitPushConstants.privateDatabaseSubscriptionID,
            let environment = AppRuntime.shared.environment
        else {
            completionHandler(.noData)
            return
        }

        Task { @MainActor in
            AppRuntime.shared.log("received matching CloudKit remote notification")
            environment.syncStatusStore.markDebugTrigger(.push)
            await environment.performSyncIfNeeded()
            AppRuntime.shared.log("remote notification sync finished")
            completionHandler(.newData)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        AppRuntime.shared.log("remote notification registration failed: \(error)")
    }
}

@main
struct MyNotesApp: App {
    @UIApplicationDelegateAdaptor(IOSAppDelegate.self) private var appDelegate
    @State private var coordinator = AppCoordinator()
    private let environment: AppEnvironment

    init() {
        let environment = AppEnvironment.bootstrap()
        self.environment = environment
        AppRuntime.shared.environment = environment
    }

    var body: some Scene {
        WindowGroup {
            IPhoneRootView(coordinator: coordinator, environment: environment)
        }
    }
}
#endif

import CloudKit
import Foundation
import SwiftUI
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
            guard self.isApplicationActive else { return }

            self.log("active polling tick")
            environment.syncStatusStore.markDebugTrigger(.timer)
            Task { @MainActor in
                await environment.performSyncIfNeeded()
                self.log("active polling sync finished")
                NotificationCenter.default.post(name: .scriptoriaDidApplyRemoteSync, object: nil)
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

    private var isApplicationActive: Bool {
#if os(macOS)
        NSApp.isActive
#else
        UIApplication.shared.applicationState == .active
#endif
    }

    func log(_ message: String) {
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date())
        NSLog("[ScriptoriaSync][%@] %@", timestamp, message)
    }
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
                NotificationCenter.default.post(name: .scriptoriaDidApplyRemoteSync, object: nil)
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
            NotificationCenter.default.post(name: .scriptoriaDidApplyRemoteSync, object: nil)
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

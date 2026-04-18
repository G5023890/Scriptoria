import Foundation

struct BootstrapApplicationUseCase {
    let databaseManager: DatabaseManager
    let seedSampleDataUseCase: SeedSampleDataUseCase
    let refreshToDoNotificationsUseCase: RefreshToDoNotificationsUseCase
    let storageCleanupUseCase: StorageCleanupUseCase

    func execute() async {
        do {
            try databaseManager.prepareIfNeeded()
            await storageCleanupUseCase.executeIfNeeded()
            try await seedSampleDataUseCase.executeIfNeeded()
            await refreshToDoNotificationsUseCase.execute(promptIfNeeded: false)
        } catch {
            print("Bootstrap failed: \(error)")
        }
    }
}

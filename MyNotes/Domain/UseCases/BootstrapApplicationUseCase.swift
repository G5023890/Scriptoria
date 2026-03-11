import Foundation

struct BootstrapApplicationUseCase {
    let databaseManager: DatabaseManager
    let seedSampleDataUseCase: SeedSampleDataUseCase
    let refreshToDoNotificationsUseCase: RefreshToDoNotificationsUseCase

    func execute() async {
        do {
            try databaseManager.prepareIfNeeded()
            try await seedSampleDataUseCase.executeIfNeeded()
            await refreshToDoNotificationsUseCase.execute(promptIfNeeded: false)
        } catch {
            print("Bootstrap failed: \(error)")
        }
    }
}

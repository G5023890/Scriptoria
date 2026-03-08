import Foundation

struct BootstrapApplicationUseCase {
    let databaseManager: DatabaseManager
    let seedSampleDataUseCase: SeedSampleDataUseCase

    func execute() async {
        do {
            try databaseManager.prepareIfNeeded()
            try await seedSampleDataUseCase.executeIfNeeded()
        } catch {
            print("Bootstrap failed: \(error)")
        }
    }
}

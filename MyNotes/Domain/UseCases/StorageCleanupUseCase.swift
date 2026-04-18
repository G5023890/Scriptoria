import Foundation

struct StorageCleanupUseCase {
    let attachmentsDataSource: AttachmentsLocalDataSource
    let fileService: any FileService
    let syncStateRepository: any SyncStateRepository

    func execute(forceCloudKitCachePurge: Bool = false) async throws -> StorageCleanupReport {
        let retainedRelativePaths = try Set(
            attachmentsDataSource
                .allAttachmentsIncludingDeleted()
                .map(\.relativePath)
                .filter { !$0.isEmpty }
        )

        let report = try fileService.cleanupStorage(
            retainingAttachmentRelativePaths: retainedRelativePaths,
            maximumRetainedBackups: 2,
            purgeCloudKitAssetCache: forceCloudKitCachePurge
        )

        try await syncStateRepository.setValue("1", for: .hasCompletedInitialStorageCleanup)
        return report
    }

    func executeIfNeeded(forceCloudKitCachePurge: Bool = false) async {
        let hasCompletedCleanup = (try? await syncStateRepository.value(for: .hasCompletedInitialStorageCleanup)) == "1"
        guard !hasCompletedCleanup || forceCloudKitCachePurge else { return }

        do {
            _ = try await execute(forceCloudKitCachePurge: forceCloudKitCachePurge)
        } catch {
            print("Storage cleanup failed: \(error)")
        }
    }
}

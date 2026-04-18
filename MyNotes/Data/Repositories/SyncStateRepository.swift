import Foundation

protocol SyncStateRepository: Sendable {
    func value(for key: SyncStateKey) async throws -> String?
    func setValue(_ value: String?, for key: SyncStateKey) async throws
    func lastSuccessfulSyncDate() async throws -> Date?
    func setLastSuccessfulSyncDate(_ date: Date?) async throws
}

enum SyncStateKey: String, Sendable {
    case databaseChangeToken
    case databaseSubscriptionInstalled
    case zoneChangeToken
    case hasCompletedInitialCloudSync
    case hasCompletedInitialStorageCleanup
    case lastSuccessfulSyncDate
    case lastFailureSummary
}

actor LocalSyncStateRepository: SyncStateRepository {
    private let dataSource: SyncLocalDataSource
    private let dateService: any DateService

    init(dataSource: SyncLocalDataSource, dateService: any DateService) {
        self.dataSource = dataSource
        self.dateService = dateService
    }

    func value(for key: SyncStateKey) async throws -> String? {
        try dataSource.value(for: key.rawValue)
    }

    func setValue(_ value: String?, for key: SyncStateKey) async throws {
        try dataSource.setValue(value, for: key.rawValue, updatedAt: dateService.now())
    }

    func lastSuccessfulSyncDate() async throws -> Date? {
        guard let rawValue = try await value(for: .lastSuccessfulSyncDate) else {
            return nil
        }
        return try DatabaseDateCodec.decode(rawValue)
    }

    func setLastSuccessfulSyncDate(_ date: Date?) async throws {
        let encodedDate = date.map(DatabaseDateCodec.encode)
        try await setValue(encodedDate, for: .lastSuccessfulSyncDate)
    }
}

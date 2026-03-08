import Foundation

struct SyncQueueItem: Identifiable, Hashable, Sendable {
    enum EntityType: String, Hashable, Sendable {
        case note
        case label
        case attachment
        case snippet
        case noteLabel
    }

    enum Operation: String, Hashable, Sendable {
        case create
        case update
        case delete
    }

    enum Status: String, Hashable, Sendable {
        case pending
        case processing
        case failed
    }

    let id: String
    let entityType: EntityType
    let entityID: String
    let operation: Operation
    let payloadVersion: Int
    let status: Status
    let createdAt: Date
    let retryCount: Int
    let nextRetryAt: Date?
    let lastAttemptAt: Date?
    let lastError: String?
}

struct SyncEnqueueRequest: Sendable {
    let entityType: SyncQueueItem.EntityType
    let entityID: String
    let operation: SyncQueueItem.Operation
    let payloadVersion: Int
}

protocol SyncQueue: Sendable {
    func enqueuePendingLocalChange(_ request: SyncEnqueueRequest) async throws -> SyncQueueItem
    func pendingItems(limit: Int) async throws -> [SyncQueueItem]
    func pendingCount() async throws -> Int
    func markProcessing(itemID: String, attemptedAt: Date) async throws
    func markSucceeded(itemID: String) async throws
    func markFailed(itemID: String, attemptedAt: Date, errorSummary: String?) async throws
}

actor LocalSyncQueue: SyncQueue {
    private let dataSource: SyncLocalDataSource
    private let dateService: any DateService

    init(dataSource: SyncLocalDataSource, dateService: any DateService) {
        self.dataSource = dataSource
        self.dateService = dateService
    }

    func enqueuePendingLocalChange(_ request: SyncEnqueueRequest) async throws -> SyncQueueItem {
        let item = SyncQueueItem(
            id: UUID().uuidString.lowercased(),
            entityType: request.entityType,
            entityID: request.entityID,
            operation: request.operation,
            payloadVersion: max(1, request.payloadVersion),
            status: .pending,
            createdAt: dateService.now(),
            retryCount: 0,
            nextRetryAt: nil,
            lastAttemptAt: nil,
            lastError: nil
        )
        try dataSource.enqueue(item)
        return item
    }

    func pendingItems(limit: Int) async throws -> [SyncQueueItem] {
        try dataSource.pendingItems(readyBefore: dateService.now(), limit: limit)
    }

    func pendingCount() async throws -> Int {
        try dataSource.pendingCount(readyBefore: dateService.now())
    }

    func markProcessing(itemID: String, attemptedAt: Date) async throws {
        try dataSource.markProcessing(itemID: itemID, attemptedAt: attemptedAt)
    }

    func markSucceeded(itemID: String) async throws {
        try dataSource.removeProcessedItem(itemID: itemID)
    }

    func markFailed(itemID: String, attemptedAt: Date, errorSummary: String?) async throws {
        let currentItem = try dataSource.queueItem(id: itemID)
        let nextRetryCount = (currentItem?.retryCount ?? 0) + 1
        let nextRetryAt = attemptedAt.addingTimeInterval(retryDelay(for: nextRetryCount))
        try dataSource.markFailed(
            itemID: itemID,
            retryCount: nextRetryCount,
            nextRetryAt: nextRetryAt,
            attemptedAt: attemptedAt,
            errorSummary: errorSummary
        )
    }

    private func retryDelay(for retryCount: Int) -> TimeInterval {
        let baseDelay: TimeInterval = 30
        let multiplier = pow(2.0, Double(max(0, retryCount - 1)))
        return min(baseDelay * multiplier, 60 * 60 * 6)
    }
}

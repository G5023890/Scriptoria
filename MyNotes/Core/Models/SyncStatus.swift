import Foundation
import Observation

enum SyncStatus: Sendable, Equatable {
    case idle
    case syncing
    case success(Date)
    case failed(String)
    case offlinePending(Int)

    var summary: String {
        switch self {
        case .idle:
            "Idle"
        case .syncing:
            "Syncing"
        case .success(let date):
            "Synced \(date.formatted(date: .abbreviated, time: .shortened))"
        case .failed(let message):
            "Failed: \(message)"
        case .offlinePending(let pendingCount):
            pendingCount == 1 ? "1 change pending" : "\(pendingCount) changes pending"
        }
    }
}

@MainActor
@Observable
final class SyncStatusStore {
    var status: SyncStatus = .idle

    func update(_ status: SyncStatus) {
        self.status = status
    }
}

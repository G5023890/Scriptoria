import Foundation
import Observation

enum SyncDebugTrigger: String, Sendable, Equatable {
    case idle
    case active
    case timer
    case push
    case stopped

    var label: String {
        rawValue
    }
}

enum SyncStatus: Sendable, Equatable {
    case idle
    case syncing
    case success(Date)
    case failed(String)
    case offlinePending(Int)
    case unavailable(String)

    var summary: String {
        switch self {
        case .idle:
            "Idle"
        case .syncing:
            "Syncing"
        case .success(let date):
            "Synced \(date.fixedDateTimeString())"
        case .failed(let message):
            "Failed: \(message)"
        case .offlinePending(let pendingCount):
            pendingCount == 1 ? "1 change pending" : "\(pendingCount) changes pending"
        case .unavailable(let message):
            "Sync unavailable: \(message)"
        }
    }
}

@MainActor
@Observable
final class SyncStatusStore {
    var status: SyncStatus = .idle
    var lastDebugTrigger: SyncDebugTrigger = .idle
    var lastDebugAt: Date?
    var isForegroundPollingActive = false

    func update(_ status: SyncStatus) {
        self.status = status
    }

    func markDebugTrigger(_ trigger: SyncDebugTrigger, at date: Date = Date()) {
        lastDebugTrigger = trigger
        lastDebugAt = date
    }
}

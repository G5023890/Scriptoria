import Foundation

struct SyncPolicy {
    func mergedLabelIDs(local: [LabelID], remote: [LabelID]) -> [LabelID] {
        Array(Set(local).union(remote)).sorted { $0.rawValue < $1.rawValue }
    }
}

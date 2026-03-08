import Foundation

struct SidebarLabelSummary: Identifiable, Hashable, Sendable {
    let label: Label
    let noteCount: Int

    var id: LabelID { label.id }
}

struct SidebarData: Sendable {
    let collectionCounts: [SmartCollection: Int]
    let labels: [SidebarLabelSummary]
}

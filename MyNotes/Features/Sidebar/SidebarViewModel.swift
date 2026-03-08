import Foundation
import Observation

@MainActor
@Observable
final class SidebarViewModel {
    var selection: SidebarSelection = .collection(.allNotes)
    var counts: [SmartCollection: Int] = [:]
    var labels: [SidebarLabelSummary] = []

    private let loadSidebarDataUseCase: LoadSidebarDataUseCase
    private let onEmptyTrashRequested: @MainActor () -> Void

    init(loadSidebarDataUseCase: LoadSidebarDataUseCase, onEmptyTrashRequested: @escaping @MainActor () -> Void) {
        self.loadSidebarDataUseCase = loadSidebarDataUseCase
        self.onEmptyTrashRequested = onEmptyTrashRequested
    }

    func reload() async {
        do {
            let sidebarData = try await loadSidebarDataUseCase.execute()
            counts = sidebarData.collectionCounts
            labels = sidebarData.labels
        } catch {
            counts = [:]
            labels = []
        }
    }

    func noteCount(for collection: SmartCollection) -> Int {
        counts[collection] ?? 0
    }

    func noteCount(for labelID: LabelID) -> Int {
        labels.first(where: { $0.label.id == labelID })?.noteCount ?? 0
    }

    func labelName(for labelID: LabelID) -> String? {
        labels.first(where: { $0.label.id == labelID })?.label.name
    }

    func requestEmptyTrash() {
        onEmptyTrashRequested()
    }
}

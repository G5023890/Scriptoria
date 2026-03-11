import Foundation
import Observation

@MainActor
@Observable
final class SidebarViewModel {
    var selection: SidebarSelection = .collection(.allNotes)
    var counts: [SmartCollection: Int] = [:]
    var labels: [SidebarLabelSummary] = []
    var labelBeingRenamed: SidebarLabelSummary?
    var draftLabelName = ""
    var errorMessage: String?
    var labelsMutationID = UUID()

    private let loadSidebarDataUseCase: LoadSidebarDataUseCase
    private let renameLabelUseCase: RenameLabelUseCase
    private let deleteLabelUseCase: DeleteLabelUseCase
    private let onEmptyTrashRequested: @MainActor () -> Void

    init(
        loadSidebarDataUseCase: LoadSidebarDataUseCase,
        renameLabelUseCase: RenameLabelUseCase,
        deleteLabelUseCase: DeleteLabelUseCase,
        onEmptyTrashRequested: @escaping @MainActor () -> Void
    ) {
        self.loadSidebarDataUseCase = loadSidebarDataUseCase
        self.renameLabelUseCase = renameLabelUseCase
        self.deleteLabelUseCase = deleteLabelUseCase
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

    func beginRename(for item: SidebarLabelSummary) {
        guard !item.label.isSystem else { return }
        labelBeingRenamed = item
        draftLabelName = item.label.name
    }

    func cancelRename() {
        labelBeingRenamed = nil
        draftLabelName = ""
    }

    func saveRenamedLabel() async {
        guard let item = labelBeingRenamed else { return }

        do {
            let trimmedName = draftLabelName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else {
                errorMessage = "Label name can't be empty."
                return
            }

            _ = try await renameLabelUseCase.execute(labelID: item.label.id, newName: trimmedName)
            cancelRename()
            await reload()
            labelsMutationID = UUID()
        } catch {
            errorMessage = "Label rename failed: \(error.localizedDescription)"
        }
    }

    func deleteLabel(_ item: SidebarLabelSummary) async {
        guard !item.label.isSystem else { return }
        do {
            try await deleteLabelUseCase.execute(labelID: item.label.id)
            if selection == .label(item.label.id) {
                selection = .collection(.allNotes)
            }
            await reload()
            labelsMutationID = UUID()
        } catch {
            errorMessage = "Label delete failed: \(error.localizedDescription)"
        }
    }

    func clearError() {
        errorMessage = nil
    }
}

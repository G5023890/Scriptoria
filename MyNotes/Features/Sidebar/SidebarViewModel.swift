import Foundation
import Observation

@MainActor
@Observable
final class SidebarViewModel {
    var selection: SidebarSelection = .collection(.allNotes)
    var counts: [SmartCollection: Int] = [:]
    var labels: [SidebarLabelSummary] = []
    var labelBeingEdited: SidebarLabelSummary?
    var draftLabelName = ""
    var draftLabelIconName = LabelAppearanceCatalog.defaultIconName
    var draftLabelColorHex: String?
    var errorMessage: String?
    var labelsMutationID = UUID()

    private let loadSidebarDataUseCase: LoadSidebarDataUseCase
    private let updateLabelUseCase: UpdateLabelUseCase
    private let deleteLabelUseCase: DeleteLabelUseCase
    private let onEmptyTrashRequested: @MainActor () -> Void

    init(
        loadSidebarDataUseCase: LoadSidebarDataUseCase,
        updateLabelUseCase: UpdateLabelUseCase,
        deleteLabelUseCase: DeleteLabelUseCase,
        onEmptyTrashRequested: @escaping @MainActor () -> Void
    ) {
        self.loadSidebarDataUseCase = loadSidebarDataUseCase
        self.updateLabelUseCase = updateLabelUseCase
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

    func beginEditing(for item: SidebarLabelSummary) {
        labelBeingEdited = item
        draftLabelName = item.label.name
        draftLabelIconName = item.label.iconName ?? LabelAppearanceCatalog.defaultIconName
        draftLabelColorHex = LabelAppearanceCatalog.normalizedHex(item.label.color)
    }

    func cancelEditing() {
        labelBeingEdited = nil
        draftLabelName = ""
        draftLabelIconName = LabelAppearanceCatalog.defaultIconName
        draftLabelColorHex = nil
    }

    func saveEditedLabel() async {
        guard let item = labelBeingEdited else { return }

        do {
            _ = try await updateLabelUseCase.execute(
                labelID: item.label.id,
                newName: draftLabelName,
                color: draftLabelColorHex,
                iconName: draftLabelIconName
            )
            cancelEditing()
            await reload()
            labelsMutationID = UUID()
        } catch {
            errorMessage = "Label update failed: \(error.localizedDescription)"
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

    var draftHasLegacyIcon: Bool {
        LabelAppearanceCatalog.isLegacyIcon(draftLabelIconName)
    }

    var draftHasCustomColor: Bool {
        draftLabelColorHex != nil && !LabelAppearanceCatalog.isPaletteColor(draftLabelColorHex)
    }

    func selectDraftIcon(_ iconName: String) {
        draftLabelIconName = iconName
    }

    func selectDraftColor(_ colorHex: String?) {
        draftLabelColorHex = LabelAppearanceCatalog.normalizedHex(colorHex)
    }
}

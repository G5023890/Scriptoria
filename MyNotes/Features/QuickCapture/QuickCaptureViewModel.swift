import Observation

@MainActor
@Observable
final class QuickCaptureViewModel {
    var title = ""
    var body = ""
    var isPinned = false
    var isFavorite = false
    var availableLabels: [Label] = []
    var selectedLabelIDs: Set<LabelID> = []
    var isSaving = false

    private let listLabelsUseCase: ListLabelsUseCase
    private let quickCaptureUseCase: QuickCaptureUseCase

    init(listLabelsUseCase: ListLabelsUseCase, quickCaptureUseCase: QuickCaptureUseCase) {
        self.listLabelsUseCase = listLabelsUseCase
        self.quickCaptureUseCase = quickCaptureUseCase
    }

    func load() async {
        availableLabels = (try? await listLabelsUseCase.execute()) ?? []
    }

    func toggleLabel(_ labelID: LabelID) {
        if selectedLabelIDs.contains(labelID) {
            selectedLabelIDs.remove(labelID)
        } else {
            selectedLabelIDs.insert(labelID)
        }
    }

    func capture() async -> Note? {
        isSaving = true
        defer { isSaving = false }

        do {
            let note = try await quickCaptureUseCase.execute(
                title: title,
                bodyMarkdown: body,
                labelIDs: Array(selectedLabelIDs),
                isPinned: isPinned,
                isFavorite: isFavorite
            )
            resetDraft()
            return note
        } catch {
            return nil
        }
    }

    func resetDraft() {
        title = ""
        body = ""
        isPinned = false
        isFavorite = false
        selectedLabelIDs = []
    }
}

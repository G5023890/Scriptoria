import Foundation

struct RenameLabelUseCase {
    let labelsRepository: any LabelsRepository
    let dateService: any DateService

    func execute(labelID: LabelID, newName: String) async throws -> Label? {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        let existingLabels = try await labelsRepository.allLabels()
        if existingLabels.contains(where: {
            $0.id != labelID &&
            $0.name.compare(trimmedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            return existingLabels.first(where: { $0.id == labelID })
        }

        guard var label = existingLabels.first(where: { $0.id == labelID }) else {
            return nil
        }

        guard label.name != trimmedName else { return label }

        label.name = trimmedName
        label.updatedAt = dateService.now()
        label.version += 1

        try await labelsRepository.rename(labelID: labelID, to: trimmedName, updatedAt: label.updatedAt)
        return label
    }
}

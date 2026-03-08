import Foundation

struct CreateLabelUseCase {
    let labelsRepository: any LabelsRepository
    let dateService: any DateService

    func execute(name: String) async throws -> Label? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        let existingLabels = try await labelsRepository.allLabels()
        if let existingLabel = existingLabels.first(where: {
            $0.name.compare(trimmedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            return existingLabel
        }

        let now = dateService.now()
        let label = Label(
            id: LabelID(),
            name: trimmedName,
            color: nil,
            iconName: nil,
            isSystem: false,
            createdAt: now,
            updatedAt: now,
            isDeleted: false,
            deletedAt: nil,
            version: 1
        )
        try await labelsRepository.create(label: label)
        return label
    }
}

import Foundation

struct UpdateLabelUseCase {
    enum Error: LocalizedError {
        case emptyName
        case duplicateName
        case labelNotFound

        var errorDescription: String? {
            switch self {
            case .emptyName:
                return "Label name can't be empty."
            case .duplicateName:
                return "A label with this name already exists."
            case .labelNotFound:
                return "The label could not be found."
            }
        }
    }

    let labelsRepository: any LabelsRepository
    let dateService: any DateService

    func execute(labelID: LabelID, newName: String, color: String?, iconName: String?) async throws -> Label {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw Error.emptyName
        }

        let existingLabels = try await labelsRepository.allLabels()
        if existingLabels.contains(where: {
            $0.id != labelID &&
            $0.name.compare(trimmedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            throw Error.duplicateName
        }

        guard var label = existingLabels.first(where: { $0.id == labelID }) else {
            throw Error.labelNotFound
        }

        let nextIconName = iconName ?? LabelAppearanceCatalog.defaultIconName
        let normalizedColor = LabelAppearanceCatalog.normalizedHex(color)

        label.name = trimmedName
        label.color = normalizedColor
        label.iconName = nextIconName
        label.updatedAt = dateService.now()
        label.version += 1

        try await labelsRepository.update(label: label)
        return label
    }
}

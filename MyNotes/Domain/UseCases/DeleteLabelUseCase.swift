import Foundation

struct DeleteLabelUseCase {
    let labelsRepository: any LabelsRepository
    let dateService: any DateService

    func execute(labelID: LabelID) async throws {
        try await labelsRepository.delete(labelID: labelID, deletedAt: dateService.now())
    }
}

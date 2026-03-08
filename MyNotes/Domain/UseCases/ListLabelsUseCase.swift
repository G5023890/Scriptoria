import Foundation

struct ListLabelsUseCase {
    let labelsRepository: any LabelsRepository

    func execute() async throws -> [Label] {
        try await labelsRepository.allLabels()
    }
}

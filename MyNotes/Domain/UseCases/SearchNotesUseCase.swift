import Foundation

struct SearchNotesUseCase {
    let searchRepository: any SearchRepository
    let searchPolicy: SearchPolicy

    func execute(rawQuery: String) async throws -> [SearchResult] {
        try await searchRepository.search(parse(rawQuery: rawQuery))
    }

    func parse(rawQuery: String) -> SearchQuery {
        searchPolicy.parse(rawQuery: rawQuery)
    }
}

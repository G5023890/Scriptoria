import Foundation

protocol SearchRepository {
    func search(_ query: SearchQuery) async throws -> [SearchResult]
}

struct LocalSearchRepository: SearchRepository {
    let dataSource: SearchLocalDataSource
    let searchPolicy: SearchPolicy

    func search(_ query: SearchQuery) async throws -> [SearchResult] {
        guard !query.terms.isEmpty || !query.filters.isEmpty else { return [] }

        let rankedDocuments: [SearchDocumentMatch]
        if query.terms.isEmpty {
            rankedDocuments = try dataSource.allDocuments().map { SearchDocumentMatch(document: $0, rank: 0) }
        } else {
            do {
                rankedDocuments = try dataSource.searchDocuments(matching: query)
            } catch {
                rankedDocuments = try dataSource.allDocuments().map { SearchDocumentMatch(document: $0, rank: 0) }
            }
        }

        let rankedResults = rankedDocuments.compactMap { match -> (SearchResult, Double)? in
            guard let baseResult = searchPolicy.match(query: query, document: match.document) else {
                return nil
            }

            let boostedScore = baseResult.score + scoreBoost(for: match.rank)
            let result = SearchResult(
                id: baseResult.id,
                noteID: baseResult.noteID,
                title: baseResult.title,
                excerpt: baseResult.excerpt,
                matchedField: baseResult.matchedField,
                kind: baseResult.kind,
                score: boostedScore
            )
            return (result, match.rank)
        }

        return rankedResults
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return lhs.1 < rhs.1
                }
                if lhs.0.score != rhs.0.score {
                    return lhs.0.score > rhs.0.score
                }
                return lhs.0.title.localizedCaseInsensitiveCompare(rhs.0.title) == .orderedAscending
            }
            .map(\.0)
    }

    private func scoreBoost(for rank: Double) -> Int {
        guard rank.isFinite else { return 0 }
        return max(0, 100 - min(100, Int(abs(rank) * 10)))
    }
}

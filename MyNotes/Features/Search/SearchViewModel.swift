import Observation

@MainActor
@Observable
final class SearchViewModel {
    enum QuickFilter: CaseIterable, Identifiable {
        case pinned
        case favorite
        case attachments
        case code

        var id: String { token }

        var title: String {
            switch self {
            case .pinned: "Pinned"
            case .favorite: "Favorites"
            case .attachments: "Attachments"
            case .code: "Code"
            }
        }

        var token: String {
            switch self {
            case .pinned: "is:pinned"
            case .favorite: "is:favorite"
            case .attachments: "has:attachments"
            case .code: "has:snippets"
            }
        }
    }

    var queryText = ""
    var results: [SearchResult] = []
    var activeFilterLabels: [String] = []
    var isLoading = false

    private let searchNotesUseCase: SearchNotesUseCase
    private var searchTask: Task<Void, Never>?

    init(searchNotesUseCase: SearchNotesUseCase) {
        self.searchNotesUseCase = searchNotesUseCase
    }

    var isSearching: Bool {
        !queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func updateQuery(_ query: String) {
        queryText = query
        activeFilterLabels = filterLabels(for: query)
        searchTask?.cancel()

        guard isSearching else {
            results = []
            isLoading = false
            return
        }

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }

    func refresh() async {
        let query = queryText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            results = []
            isLoading = false
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            results = try await searchNotesUseCase.execute(rawQuery: query)
        } catch {
            results = []
        }
    }

    func toggleQuickFilter(_ filter: QuickFilter) {
        var tokens = queryText
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        if let index = tokens.firstIndex(where: { $0.caseInsensitiveCompare(filter.token) == .orderedSame }) {
            tokens.remove(at: index)
        } else {
            tokens.append(filter.token)
        }

        updateQuery(tokens.joined(separator: " "))
    }

    func isQuickFilterActive(_ filter: QuickFilter) -> Bool {
        searchNotesUseCase
            .parse(rawQuery: queryText)
            .filters
            .contains(where: { currentFilter in
                switch (filter, currentFilter) {
                case (.pinned, .pinned), (.favorite, .favorite), (.attachments, .withAttachments), (.code, .withSnippets):
                    true
                default:
                    false
                }
            })
    }

    private func filterLabels(for query: String) -> [String] {
        searchNotesUseCase.parse(rawQuery: query).filters.map { filter in
            switch filter {
            case .pinned:
                "Pinned"
            case .favorite:
                "Favorite"
            case .withAttachments:
                "Has Attachments"
            case .withSnippets:
                "Has Snippets"
            case .label(let label):
                "Label: \(label)"
            case .type(let type):
                "Type: \(type.rawValue)"
            case .updatedToday:
                "Updated Today"
            case .updatedThisWeek:
                "Updated This Week"
            case .language(let language):
                "Language: \(language)"
            case .field(let field):
                "In \(field.title)"
            case .resultKind(let kind):
                "Kind: \(kind.rawValue.capitalized)"
            }
        }
    }
}

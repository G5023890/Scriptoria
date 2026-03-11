import Observation

@MainActor
@Observable
final class SearchViewModel {
    enum QuickFilter: CaseIterable, Identifiable {
        case pinned
        case favorite
        case tasks
        case attachments
        case code

        var id: String { token }

        var symbolName: String {
            switch self {
            case .pinned: "pin"
            case .favorite: "star"
            case .tasks: "checklist"
            case .attachments: "paperclip.badge.ellipsis"
            case .code: "chevron.left.slash.chevron.right"
            }
        }

        var token: String {
            switch self {
            case .pinned: "is:pinned"
            case .favorite: "is:favorite"
            case .tasks: "has:tasks"
            case .attachments: "has:attachments"
            case .code: "has:snippets"
            }
        }
    }

    var queryText = ""
    var results: [SearchResult] = []
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
                case (.pinned, .pinned),
                    (.favorite, .favorite),
                    (.tasks, .withTasks),
                    (.attachments, .withAttachments),
                    (.code, .withSnippets):
                    true
                default:
                    false
                }
            })
    }
}

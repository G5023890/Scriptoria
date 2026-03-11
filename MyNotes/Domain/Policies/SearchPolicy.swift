import Foundation

struct SearchPolicy {
    func parse(rawQuery: String) -> SearchQuery {
        let tokens = tokenize(rawQuery)

        var filters: [SearchFilter] = []
        var terms: [String] = []

        for token in tokens {
            let lowercased = token.lowercased()
            if lowercased == "pinned" || lowercased == "is:pinned" {
                filters.append(.pinned)
            } else if lowercased == "favorite" || lowercased == "favorites" || lowercased == "is:favorite" {
                filters.append(.favorite)
            } else if lowercased == "task" || lowercased == "tasks" || lowercased == "has:task" || lowercased == "has:tasks" {
                filters.append(.withTasks)
            } else if lowercased == "attachments" || lowercased == "has:attachment" || lowercased == "has:attachments" {
                filters.append(.withAttachments)
            } else if lowercased == "snippets" || lowercased == "snippet" || lowercased == "has:snippet" || lowercased == "has:snippets" {
                filters.append(.withSnippets)
            } else if lowercased.hasPrefix("label:") {
                filters.append(.label(String(lowercased.dropFirst("label:".count))))
            } else if lowercased.hasPrefix("type:") {
                let value = String(lowercased.dropFirst("type:".count))
                if let type = NotePrimaryType(rawValue: value) {
                    filters.append(.type(type))
                }
            } else if lowercased == "updated:today" {
                filters.append(.updatedToday)
            } else if lowercased == "updated:week" || lowercased == "updated:thisweek" {
                filters.append(.updatedThisWeek)
            } else if lowercased.hasPrefix("language:") {
                filters.append(.language(String(lowercased.dropFirst("language:".count))))
            } else if lowercased.hasPrefix("kind:") {
                let value = String(lowercased.dropFirst("kind:".count))
                if let kind = SearchResult.Kind(rawValue: value) {
                    filters.append(.resultKind(kind))
                }
            } else if lowercased.hasPrefix("in:") || lowercased.hasPrefix("field:") {
                let prefix = lowercased.hasPrefix("in:") ? "in:" : "field:"
                let value = String(lowercased.dropFirst(prefix.count))
                if let field = parseField(value) {
                    filters.append(.field(field))
                }
            } else {
                terms.append(lowercased)
            }
        }

        return SearchQuery(rawValue: rawQuery, terms: terms, filters: filters)
    }

    func match(
        query: SearchQuery,
        document: SearchDocument
    ) -> SearchResult? {
        guard satisfiesFilters(query.filters, document: document) else {
            return nil
        }

        let allowedFields = allowedFields(from: query.filters)
        let allowedKinds = allowedKinds(from: query.filters)
        let fields: [(String, String, SearchResult.Kind)] = [
            (document.title, "Title", .note),
            (document.bodyPlainText, "Content", .note),
            (document.labelsText, "Labels", .label),
            (document.snippetsText, "Code", .snippet),
            (document.attachmentNames, "Attachments", .attachment)
        ].filter { candidate in
            allowedFields.isEmpty || allowedFields.contains(field(for: candidate.1))
        }
        .filter { candidate in
            allowedKinds.isEmpty || allowedKinds.contains(candidate.2)
        }

        let scoredFields = fields.compactMap { fieldValue, fieldName, kind -> (Int, String, String, SearchResult.Kind)? in
            let lowercasedField = fieldValue.lowercased()
            let score = query.terms.reduce(into: 0) { partialResult, term in
                if lowercasedField.contains(term) {
                    partialResult += lowercasedField == term ? 4 : 2
                }
            }
            guard score > 0 || query.terms.isEmpty else { return nil }
            return (score, fieldName, fieldValue, kind)
        }

        guard let best = scoredFields.max(by: { lhs, rhs in lhs.0 < rhs.0 }) else {
            return nil
        }

        return SearchResult(
            id: "\(document.id.rawValue)-\(best.1.lowercased())",
            noteID: document.id,
            title: document.title,
            excerpt: String(best.2.prefix(160)),
            matchedField: best.1,
            kind: best.3,
            score: max(best.0, 1)
        )
    }

    private func satisfiesFilters(_ filters: [SearchFilter], document: SearchDocument) -> Bool {
        let calendar = Calendar.current
        return filters.allSatisfy { filter in
            switch filter {
            case .pinned:
                return document.isPinned
            case .favorite:
                return document.isFavorite
            case .withTasks:
                return document.hasTasks
            case .withAttachments:
                return document.hasAttachments
            case .withSnippets:
                return !document.snippetsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .label(let labelName):
                return document.labelsText.lowercased().contains(labelName.lowercased())
            case .type(let type):
                return document.primaryType == type
            case .updatedToday:
                return calendar.isDateInToday(document.updatedAt)
            case .updatedThisWeek:
                guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else {
                    return false
                }
                return document.updatedAt >= weekAgo
            case .language(let language):
                return document.languagesText.lowercased().contains(language.lowercased()) ||
                    document.snippetLanguageHint?.lowercased() == language.lowercased()
            case .field, .resultKind:
                return true
            }
        }
    }

    private func tokenize(_ rawQuery: String) -> [String] {
        let pattern = #""([^"]+)"|(\S+)"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return rawQuery
                .split(whereSeparator: \.isWhitespace)
                .map(String.init)
                .filter { !$0.isEmpty }
        }

        let range = NSRange(rawQuery.startIndex..<rawQuery.endIndex, in: rawQuery)
        return expression.matches(in: rawQuery, range: range).compactMap { match in
            for captureIndex in 1..<match.numberOfRanges {
                let captureRange = match.range(at: captureIndex)
                guard captureRange.location != NSNotFound, let range = Range(captureRange, in: rawQuery) else {
                    continue
                }
                return String(rawQuery[range])
            }
            return nil
        }
    }

    private func parseField(_ value: String) -> SearchField? {
        switch value {
        case "title":
            .title
        case "body", "content", "text":
            .content
        case "label", "labels", "tag", "tags":
            .labels
        case "code", "snippet", "snippets":
            .code
        case "attachment", "attachments", "file", "files":
            .attachments
        default:
            nil
        }
    }

    private func allowedFields(from filters: [SearchFilter]) -> Set<SearchField> {
        Set(filters.compactMap {
            guard case .field(let field) = $0 else { return nil }
            return field
        })
    }

    private func allowedKinds(from filters: [SearchFilter]) -> Set<SearchResult.Kind> {
        Set(filters.compactMap {
            guard case .resultKind(let kind) = $0 else { return nil }
            return kind
        })
    }

    private func field(for matchedField: String) -> SearchField {
        switch matchedField {
        case "Title":
            .title
        case "Content":
            .content
        case "Labels":
            .labels
        case "Code":
            .code
        case "Attachments":
            .attachments
        default:
            .content
        }
    }
}

import Foundation

struct MarkdownCodeBlock: Hashable, Sendable {
    let language: String?
    let code: String
    let startOffset: Int
    let endOffset: Int
}

protocol MarkdownService {
    func plainText(from markdown: String) -> String
    func previewText(from markdown: String, limit: Int) -> String
    func detectPrimaryType(in markdown: String) -> NotePrimaryType
    func detectSnippetLanguageHint(in markdown: String) -> String?
    func extractCodeBlocks(from markdown: String) -> [MarkdownCodeBlock]
}

struct DefaultMarkdownService: MarkdownService {
    func plainText(from markdown: String) -> String {
        let withoutCodeFences = markdown.replacingOccurrences(
            of: #"```[\s\S]*?```"#,
            with: " ",
            options: .regularExpression
        )
        let withoutMarkdownMarkers = withoutCodeFences.replacingOccurrences(
            of: #"[*_>#`\-\[\]\(\)]"#,
            with: " ",
            options: .regularExpression
        )
        return withoutMarkdownMarkers
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func previewText(from markdown: String, limit: Int = 140) -> String {
        String(plainText(from: markdown).prefix(limit))
    }

    func detectPrimaryType(in markdown: String) -> NotePrimaryType {
        let hasCode = markdown.contains("```")
        let hasImage = markdown.contains("![](") || markdown.contains("![" )
        switch (hasCode, hasImage) {
        case (true, true): return NotePrimaryType.mixed
        case (true, false): return NotePrimaryType.code
        case (false, true): return NotePrimaryType.image
        default: return NotePrimaryType.note
        }
    }

    func detectSnippetLanguageHint(in markdown: String) -> String? {
        extractCodeBlocks(from: markdown).first?.language
    }

    func extractCodeBlocks(from markdown: String) -> [MarkdownCodeBlock] {
        let pattern = #"```([A-Za-z0-9_\-+]*)\n([\s\S]*?)```"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let fullRange = NSRange(markdown.startIndex..<markdown.endIndex, in: markdown)
        return expression.matches(in: markdown, range: fullRange).compactMap { match in
            guard
                match.numberOfRanges == 3,
                let languageRange = Range(match.range(at: 1), in: markdown),
                let codeRange = Range(match.range(at: 2), in: markdown)
            else {
                return nil
            }

            let language = String(markdown[languageRange]).nilIfEmpty
            let code = String(markdown[codeRange]).trimmingCharacters(in: .newlines)
            return MarkdownCodeBlock(
                language: language,
                code: code,
                startOffset: match.range.location,
                endOffset: match.range.location + match.range.length
            )
        }
    }
}

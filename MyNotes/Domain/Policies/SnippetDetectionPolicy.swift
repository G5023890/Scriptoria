import CryptoKit
import Foundation

struct SnippetDetectionPolicy {
    let markdownService: any MarkdownService

    private let maxSnippetCount = 12
    private let maxTotalSnippetLength = 12_000
    private let maxBodyLengthForSnippetExtraction = 24_000

    func extractSnippets(from note: Note, createdAt: Date) -> [NoteSnippet] {
        guard note.bodyMarkdown.count <= maxBodyLengthForSnippetExtraction else {
            return []
        }

        let extractedBlocks = markdownService.extractCodeBlocks(from: note.bodyMarkdown)
        let totalSnippetLength = extractedBlocks.reduce(into: 0) { partialResult, block in
            partialResult += block.code.count
        }

        guard
            extractedBlocks.count <= maxSnippetCount,
            totalSnippetLength <= maxTotalSnippetLength
        else {
            return []
        }

        var duplicateCounters: [String: Int] = [:]

        return extractedBlocks.map { block in
            let language = SnippetSyntaxLanguage.normalizedID(for: block.language)
            let duplicateKey = "\(language)::\(block.code)"
            let occurrence = duplicateCounters[duplicateKey, default: 0]
            duplicateCounters[duplicateKey] = occurrence + 1

            return NoteSnippet(
                id: snippetID(
                    noteID: note.id,
                    language: language,
                    code: block.code,
                    occurrence: occurrence
                ),
                noteID: note.id,
                language: language,
                title: note.title,
                snippetDescription: nil,
                code: block.code,
                startOffset: block.startOffset,
                endOffset: block.endOffset,
                sourceType: .automatic,
                createdAt: createdAt,
                updatedAt: createdAt,
                isArchived: false,
                isDeleted: false,
                deletedAt: nil,
                version: 1
            )
        }
    }

    private func snippetID(
        noteID: NoteID,
        language: String,
        code: String,
        occurrence: Int
    ) -> String {
        let payload = "\(noteID.rawValue)|\(language.lowercased())|\(occurrence)|\(code)"
        let digest = SHA256.hash(data: Data(payload.utf8))
        let hashPrefix = digest.compactMap { String(format: "%02x", $0) }.joined().prefix(16)
        return "\(noteID.rawValue)-snippet-\(hashPrefix)"
    }
}

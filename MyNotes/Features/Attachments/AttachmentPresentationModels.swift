import Foundation

struct AttachmentItem: Identifiable, Equatable {
    let attachment: Attachment
    let title: String
    let subtitle: String
    let iconName: String
    let previewURL: URL?
    let showsInlinePreview: Bool

    var id: AttachmentID { attachment.id }
}

struct AttachmentPreviewState: Identifiable, Equatable {
    let id: AttachmentID
    let title: String
    let url: URL
}

enum AttachmentPresentationBuilder {
    static func make(
        attachment: Attachment,
        previewURL: URL?
    ) -> AttachmentItem {
        AttachmentItem(
            attachment: attachment,
            title: attachment.originalFileName,
            subtitle: subtitle(for: attachment),
            iconName: iconName(for: attachment.category),
            previewURL: previewURL,
            showsInlinePreview: attachment.category == .image && previewURL != nil
        )
    }

    private static func subtitle(for attachment: Attachment) -> String {
        var components: [String] = []
        components.append(attachment.category.rawValue.capitalized)

        if let fileSize = attachment.fileSize {
            components.append(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
        }

        if let width = attachment.width, let height = attachment.height {
            components.append("\(width)x\(height)")
        }

        if let pageCount = attachment.pageCount {
            components.append("\(pageCount) page" + (pageCount == 1 ? "" : "s"))
        }

        if let duration = attachment.duration {
            components.append(durationText(duration))
        }

        if let mimeType = attachment.mimeType {
            components.append(mimeType)
        }

        return components.joined(separator: " • ")
    }

    private static func durationText(_ duration: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "\(Int(duration))s"
    }

    private static func iconName(for category: AttachmentCategory) -> String {
        switch category {
        case .image:
            "photo"
        case .pdf:
            "doc.richtext"
        case .code:
            "curlybraces.square"
        case .video:
            "film"
        case .audio:
            "waveform"
        case .file:
            "doc"
        }
    }
}

struct SnippetItem: Identifiable, Equatable {
    let snippet: NoteSnippet
    let title: String
    let subtitle: String
    let code: String
    let selectedLanguage: String
    let displayLanguage: String

    var id: String { snippet.id }
}

@MainActor
enum SnippetPresentationBuilder {
    static func make(snippet: NoteSnippet) -> SnippetItem {
        let selectedLanguage = selectedLanguage(for: snippet)
        let displayLanguage = SnippetSyntaxLanguage.displayName(for: selectedLanguage)
        var detailParts: [String] = [snippet.sourceType == .automatic ? "Auto" : "Manual", displayLanguage]

        if let snippetDescription = snippet.snippetDescription, !snippetDescription.isEmpty {
            detailParts.append(snippetDescription)
        }

        if let startOffset = snippet.startOffset, let endOffset = snippet.endOffset {
            detailParts.append("Offsets \(startOffset)-\(endOffset)")
        }

        return SnippetItem(
            snippet: snippet,
            title: snippet.title ?? "Snippet",
            subtitle: detailParts.joined(separator: " • "),
            code: snippet.code,
            selectedLanguage: selectedLanguage,
            displayLanguage: displayLanguage
        )
    }

    static func selectedLanguage(for snippet: NoteSnippet) -> String {
        let normalized = SnippetSyntaxLanguage.normalizedID(for: snippet.language)
        if snippet.sourceType == .automatic && normalized == "plaintext" {
            return SnippetSyntaxLanguage.auto
        }

        return normalized
    }
}

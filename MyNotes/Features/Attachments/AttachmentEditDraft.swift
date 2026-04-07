import Foundation

struct AttachmentEditDraft: Identifiable, Equatable {
    let attachment: Attachment
    var description: String

    var id: AttachmentID { attachment.id }

    init(attachment: Attachment) {
        self.attachment = attachment
        description = attachment.description ?? ""
    }

    var originalFileName: String { attachment.originalFileName }

    var metadataSummary: String {
        var components: [String] = [attachment.category.rawValue.capitalized]

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
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = duration >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
            formatter.unitsStyle = .abbreviated
            components.append(formatter.string(from: duration) ?? "\(Int(duration))s")
        }

        if let mimeType = attachment.mimeType {
            components.append(mimeType)
        }

        return components.joined(separator: " • ")
    }
}

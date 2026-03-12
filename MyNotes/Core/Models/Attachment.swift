import Foundation

struct Attachment: Identifiable, Codable, Hashable, Sendable {
    let id: AttachmentID
    let noteID: NoteID
    var fileName: String
    var originalFileName: String
    var mimeType: String?
    var category: AttachmentCategory
    var relativePath: String
    var fileSize: Int64?
    var checksum: String?
    var width: Int?
    var height: Int?
    var duration: Double?
    var pageCount: Int?
    let createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var isDeleted: Bool
    var deletedAt: Date?
    var version: Int
}

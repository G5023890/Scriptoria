import Foundation

struct Label: Identifiable, Codable, Hashable, Sendable {
    let id: LabelID
    var name: String
    var color: String?
    var iconName: String?
    var isSystem: Bool
    let createdAt: Date
    var updatedAt: Date
    var isDeleted: Bool
    var deletedAt: Date?
    var version: Int
}

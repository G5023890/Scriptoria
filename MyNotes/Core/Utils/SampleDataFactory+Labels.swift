import Foundation

extension SampleDataFactory {
    static func makeLabels(now: Date) -> [Label] {
        [
            Label(
                id: LabelID(rawValue: "label-swift"),
                name: "Swift",
                color: "#F46D43",
                iconName: "swift",
                isSystem: false,
                createdAt: now,
                updatedAt: now,
                isDeleted: false,
                deletedAt: nil,
                version: 1
            ),
            Label(
                id: LabelID(rawValue: "label-regex"),
                name: "Regex",
                color: "#3887BE",
                iconName: "character.cursor.ibeam",
                isSystem: false,
                createdAt: now,
                updatedAt: now,
                isDeleted: false,
                deletedAt: nil,
                version: 1
            ),
            Label(
                id: LabelID(rawValue: "label-api"),
                name: "API",
                color: "#4B7F52",
                iconName: "network",
                isSystem: false,
                createdAt: now,
                updatedAt: now,
                isDeleted: false,
                deletedAt: nil,
                version: 1
            )
        ]
    }
}

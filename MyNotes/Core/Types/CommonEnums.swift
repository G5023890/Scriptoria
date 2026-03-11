import Foundation

enum NotePrimaryType: String, Codable, CaseIterable, Sendable {
    case note
    case code
    case image
    case mixed
    case file
}

enum AttachmentCategory: String, Codable, CaseIterable, Sendable {
    case image
    case pdf
    case code
    case video
    case audio
    case file
}

enum SmartCollection: String, CaseIterable, Hashable, Sendable, Identifiable {
    case allNotes
    case favorites
    case pinned
    case recent
    case tasks
    case attachments
    case snippets
    case trash

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allNotes: "All Notes"
        case .favorites: "Favorites"
        case .pinned: "Pinned"
        case .recent: "Recent"
        case .tasks: "Tasks"
        case .attachments: "Attachments"
        case .snippets: "Snippets"
        case .trash: "Trash"
        }
    }

    var systemImage: String {
        switch self {
        case .allNotes: "tray.full"
        case .favorites: "star"
        case .pinned: "pin"
        case .recent: "clock"
        case .tasks: "checklist"
        case .attachments: "paperclip.circle"
        case .snippets: "curlybraces.square"
        case .trash: "trash"
        }
    }
}

enum NoteSortOrder: String, Codable, Sendable {
    case pinnedThenUpdated
    case updatedDescending
    case createdDescending
    case titleAscending
}

enum NoteDetailMode: String, CaseIterable, Hashable, Sendable, Identifiable {
    case read
    case edit
    case split

    var id: String { rawValue }

    var title: String {
        switch self {
        case .read: "Read"
        case .edit: "Edit"
        case .split: "Split"
        }
    }
}

enum SearchFilter: Hashable, Sendable {
    case pinned
    case favorite
    case withTasks
    case withAttachments
    case withSnippets
    case label(String)
    case type(NotePrimaryType)
    case updatedToday
    case updatedThisWeek
    case language(String)
    case field(SearchField)
    case resultKind(SearchResult.Kind)
}

enum SearchField: String, Hashable, Sendable, CaseIterable {
    case title
    case content
    case labels
    case code
    case attachments

    var title: String {
        switch self {
        case .title: "Title"
        case .content: "Content"
        case .labels: "Labels"
        case .code: "Code"
        case .attachments: "Attachments"
        }
    }
}

struct NoteQuery: Sendable, Hashable {
    var collection: SmartCollection = .allNotes
    var labelID: LabelID?
    var includeDeleted: Bool = false
    var sortOrder: NoteSortOrder = .pinnedThenUpdated
}

struct SearchQuery: Sendable, Hashable {
    var rawValue: String
    var terms: [String]
    var filters: [SearchFilter]
}

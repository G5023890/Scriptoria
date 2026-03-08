import Foundation

struct AttachmentID: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init() {
        self.rawValue = UUID().uuidString.lowercased()
    }

    init(stringLiteral value: String) {
        self.rawValue = value
    }

    var description: String {
        rawValue
    }
}

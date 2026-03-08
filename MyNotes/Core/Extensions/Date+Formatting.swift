import Foundation

extension Date {
    func relativeDisplayString(reference: Date = .now) -> String {
        RelativeDateTimeFormatter().localizedString(for: self, relativeTo: reference)
    }
}

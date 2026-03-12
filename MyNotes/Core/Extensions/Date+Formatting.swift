import Foundation

extension Date {
    func relativeDisplayString(reference: Date = .now) -> String {
        fixedDateString(reference: reference)
    }

    func fixedDateString(reference: Date = .now) -> String {
        let formatter = Self.fixedDateFormatter(includeYear: !Calendar.current.isDate(self, equalTo: reference, toGranularity: .year))
        return formatter.string(from: self)
    }

    func fixedDateTimeString(reference: Date = .now) -> String {
        fixedDateString(reference: reference)
    }

    private static func fixedDateFormatter(includeYear: Bool) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = includeYear ? "dd.MM.yyyy" : "dd.MM"
        return formatter
    }
}

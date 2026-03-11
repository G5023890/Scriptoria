import Foundation
import UserNotifications

struct ScheduledToDoNotification: Sendable {
    let toDoID: ToDoID
    let noteID: NoteID
    let title: String
    let noteTitle: String
    let details: String
    let dueDate: Date
    let snoozedUntil: Date?
}

enum ToDoNotificationSnoozePreset: String, CaseIterable, Sendable {
    case oneHour
    case tomorrowMorning

    var actionTitle: String {
        switch self {
        case .oneHour:
            "Snooze 1 Hour"
        case .tomorrowMorning:
            "Tomorrow Morning"
        }
    }

    func snoozedUntil(from referenceDate: Date, calendar: Calendar) -> Date {
        switch self {
        case .oneHour:
            return calendar.date(byAdding: .hour, value: 1, to: referenceDate) ?? referenceDate.addingTimeInterval(3600)
        case .tomorrowMorning:
            let startOfToday = calendar.startOfDay(for: referenceDate)
            let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
            return calendar.date(byAdding: .hour, value: 9, to: startOfTomorrow) ?? startOfTomorrow
        }
    }
}

@MainActor
protocol ToDoNotificationScheduling: AnyObject {
    func configure(
        onOpenToDo: @escaping @MainActor (NoteID, ToDoID) -> Void,
        onSnoozeToDo: @escaping @MainActor (ToDoID, ToDoNotificationSnoozePreset) async -> Void,
        onCompleteToDo: @escaping @MainActor (ToDoID) async -> Void
    )
    func sync(with items: [ScheduledToDoNotification], promptIfNeeded: Bool) async
}

@MainActor
final class LocalToDoNotificationScheduler: NSObject, ToDoNotificationScheduling {
    private enum Constants {
        static let identifierPrefix = "todo-reminder:"
        static let noteIDKey = "noteID"
        static let toDoIDKey = "toDoID"
        static let fireDateKey = "fireDate"
        static let categoryIdentifier = "TODO_REMINDER"
        static let actionComplete = "TODO_COMPLETE"
        static let actionSnoozeOneHour = "TODO_SNOOZE_ONE_HOUR"
        static let actionSnoozeTomorrowMorning = "TODO_SNOOZE_TOMORROW_MORNING"
        static let maxPendingRequests = 60
        static let repeatWindowDays = 7
    }

    private enum PendingResponse: Sendable {
        case open(NoteID, ToDoID)
        case snooze(ToDoID, ToDoNotificationSnoozePreset)
        case complete(ToDoID)
    }

    private struct NotificationScheduleEntry: Sendable {
        let item: ScheduledToDoNotification
        let fireDate: Date

        var identifier: String {
            let timestamp = Int(fireDate.timeIntervalSince1970)
            return Constants.identifierPrefix + item.toDoID.rawValue + ":" + String(timestamp)
        }

        var isFollowUp: Bool {
            fireDate > max(item.dueDate, item.snoozedUntil ?? item.dueDate)
        }
    }

    private let center: UNUserNotificationCenter
    private let calendar: Calendar
    private var onOpenToDo: (@MainActor (NoteID, ToDoID) -> Void)?
    private var onSnoozeToDo: (@MainActor (ToDoID, ToDoNotificationSnoozePreset) async -> Void)?
    private var onCompleteToDo: (@MainActor (ToDoID) async -> Void)?
    private var pendingResponse: PendingResponse?

    init(
        center: UNUserNotificationCenter = .current(),
        calendar: Calendar = .current
    ) {
        self.center = center
        self.calendar = calendar
        super.init()
        center.delegate = self
        registerCategories()
    }

    func configure(
        onOpenToDo: @escaping @MainActor (NoteID, ToDoID) -> Void,
        onSnoozeToDo: @escaping @MainActor (ToDoID, ToDoNotificationSnoozePreset) async -> Void,
        onCompleteToDo: @escaping @MainActor (ToDoID) async -> Void
    ) {
        self.onOpenToDo = onOpenToDo
        self.onSnoozeToDo = onSnoozeToDo
        self.onCompleteToDo = onCompleteToDo
        center.delegate = self
        registerCategories()

        if let pendingResponse {
            self.pendingResponse = nil
            Task {
                await process(response: pendingResponse)
            }
        }
    }

    func sync(with items: [ScheduledToDoNotification], promptIfNeeded: Bool) async {
        let settings = await notificationSettings()
        let isAuthorized = await authorizationGranted(settings: settings, promptIfNeeded: promptIfNeeded)

        let pendingRequests = await pendingNotificationRequests()
        let identifiersToRemove = pendingRequests
            .map(\.identifier)
            .filter { $0.hasPrefix(Constants.identifierPrefix) }

        if !identifiersToRemove.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
            center.removeDeliveredNotifications(withIdentifiers: identifiersToRemove)
        }

        guard isAuthorized else { return }

        let scheduleEntries = buildScheduleEntries(from: items, now: Date())
        for entry in scheduleEntries.prefix(Constants.maxPendingRequests) {
            do {
                try await addNotification(for: entry)
            } catch {
                print("ToDo notification scheduling failed: \(error)")
            }
        }
    }

    private func registerCategories() {
        let actions: [UNNotificationAction] = [
            UNNotificationAction(
                identifier: Constants.actionComplete,
                title: "Complete",
                options: []
            ),
            UNNotificationAction(
                identifier: Constants.actionSnoozeOneHour,
                title: ToDoNotificationSnoozePreset.oneHour.actionTitle,
                options: []
            ),
            UNNotificationAction(
                identifier: Constants.actionSnoozeTomorrowMorning,
                title: ToDoNotificationSnoozePreset.tomorrowMorning.actionTitle,
                options: []
            )
        ]

        let category = UNNotificationCategory(
            identifier: Constants.categoryIdentifier,
            actions: actions,
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([category])
    }

    private func buildScheduleEntries(
        from items: [ScheduledToDoNotification],
        now: Date
    ) -> [NotificationScheduleEntry] {
        items
            .flatMap { buildScheduleEntries(for: $0, now: now) }
            .sorted { lhs, rhs in
                if lhs.fireDate != rhs.fireDate {
                    return lhs.fireDate < rhs.fireDate
                }
                return lhs.item.toDoID.rawValue < rhs.item.toDoID.rawValue
            }
    }

    private func buildScheduleEntries(
        for item: ScheduledToDoNotification,
        now: Date
    ) -> [NotificationScheduleEntry] {
        let anchor = max(item.dueDate, item.snoozedUntil ?? item.dueDate)
        guard let firstUpcomingDate = firstUpcomingReminderDate(anchor: anchor, now: now) else {
            return []
        }

        return (0..<Constants.repeatWindowDays).compactMap { dayOffset in
            guard let fireDate = calendar.date(byAdding: .day, value: dayOffset, to: firstUpcomingDate) else {
                return nil
            }

            return NotificationScheduleEntry(item: item, fireDate: fireDate)
        }
    }

    private func firstUpcomingReminderDate(anchor: Date, now: Date) -> Date? {
        if anchor > now {
            return anchor
        }

        let startOfAnchorDay = calendar.startOfDay(for: anchor)
        let startOfCurrentDay = calendar.startOfDay(for: now)
        let dayDelta = calendar.dateComponents([.day], from: startOfAnchorDay, to: startOfCurrentDay).day ?? 0
        let nextDayOffset = max(dayDelta, 0)
        let candidate = calendar.date(byAdding: .day, value: nextDayOffset, to: anchor) ?? anchor

        if candidate > now {
            return candidate
        }

        return calendar.date(byAdding: .day, value: 1, to: candidate)
    }

    private func authorizationGranted(settings: UNNotificationSettings, promptIfNeeded: Bool) async -> Bool {
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            guard promptIfNeeded else { return false }
            do {
                return try await requestAuthorization()
            } catch {
                print("ToDo notification authorization failed: \(error)")
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    private func requestAuthorization() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func addNotification(for entry: NotificationScheduleEntry) async throws {
        let item = entry.item
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.subtitle = item.noteTitle
        content.body = notificationBody(for: item, isFollowUp: entry.isFollowUp)
        content.sound = .default
        content.threadIdentifier = item.noteID.rawValue
        content.targetContentIdentifier = item.toDoID.rawValue
        content.categoryIdentifier = Constants.categoryIdentifier
        content.userInfo = [
            Constants.noteIDKey: item.noteID.rawValue,
            Constants.toDoIDKey: item.toDoID.rawValue,
            Constants.fireDateKey: entry.fireDate.timeIntervalSince1970
        ]

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: entry.fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: entry.identifier,
            content: content,
            trigger: trigger
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func notificationBody(for item: ScheduledToDoNotification, isFollowUp: Bool) -> String {
        if isFollowUp {
            return item.details.nilIfEmpty ?? "Task is still due."
        }

        return item.details.nilIfEmpty ?? "Task is due now."
    }

    private func responseFrom(
        actionIdentifier: String,
        noteID: NoteID,
        toDoID: ToDoID
    ) -> PendingResponse {
        switch actionIdentifier {
        case Constants.actionComplete:
            return .complete(toDoID)
        case Constants.actionSnoozeOneHour:
            return .snooze(toDoID, .oneHour)
        case Constants.actionSnoozeTomorrowMorning:
            return .snooze(toDoID, .tomorrowMorning)
        default:
            return .open(noteID, toDoID)
        }
    }

    private func process(response: PendingResponse) async {
        switch response {
        case .open(let noteID, let toDoID):
            if let onOpenToDo {
                onOpenToDo(noteID, toDoID)
                return
            }
        case .snooze(let toDoID, let preset):
            if let onSnoozeToDo {
                await onSnoozeToDo(toDoID, preset)
                return
            }
        case .complete(let toDoID):
            if let onCompleteToDo {
                await onCompleteToDo(toDoID)
                return
            }
        }

        pendingResponse = response
    }
}

extension LocalToDoNotificationScheduler: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier != UNNotificationDismissActionIdentifier else { return }

        let userInfo = response.notification.request.content.userInfo
        guard
            let noteIDValue = userInfo[Constants.noteIDKey] as? String,
            let toDoIDValue = userInfo[Constants.toDoIDKey] as? String
        else {
            return
        }

        let pendingResponse = await MainActor.run {
            self.responseFrom(
                actionIdentifier: response.actionIdentifier,
                noteID: NoteID(rawValue: noteIDValue),
                toDoID: ToDoID(rawValue: toDoIDValue)
            )
        }

        await self.process(response: pendingResponse)
    }
}

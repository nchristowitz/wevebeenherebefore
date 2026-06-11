import SwiftUI
import SwiftData
import UserNotifications

@Model
final class Episode {
    // Stable identity for notification payloads — persistentModelID changes
    // between its temporary and permanent form, so it must never be used there.
    // No @Attribute(.unique): lightweight migration can stamp all existing rows
    // with one default value, which a unique constraint would turn into a crash.
    // ensureUniqueEpisodeUUIDs() backfills duplicates at launch instead.
    var uuid: UUID = UUID()
    var title: String
    var date: Date
    var emotions: [String: Int] // Store emotion name and rating
    var prompts: [String: String] // Store prompt title and response
    var createdAt: Date
    var notificationIDs: [String] = [] // Store notification IDs for cleanup
    var dismissedCheckIns: [String] = [] // Store dismissed check-in types
    var summary: String?
    var summaryCreatedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \EpisodeNote.episode)
    var notes: [EpisodeNote] = []

    @Relationship(deleteRule: .cascade, inverse: \CheckIn.episode)
    var checkIns: [CheckIn] = []

    init(title: String, emotions: [String: Int], prompts: [String: String]) {
        self.title = title
        self.date = Date()
        self.emotions = emotions
        self.prompts = prompts
        self.createdAt = Date()
    }

    // Summary is available after 3 months (90 days)
    var canAddSummary: Bool {
        let calendar = Calendar.current
        guard let summaryAvailableDate = calendar.date(byAdding: .day, value: 90, to: self.date) else {
            return false
        }
        return Date() >= summaryAvailableDate
    }

    var hasSummary: Bool {
        guard let summary = summary else { return false }
        return !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // Helper methods for check-in logic

    // The date range during which a check-in of the given type can be added.
    // 24h: the calendar day after the episode. 2w: the target day. 3m: 5 days from the target day.
    func checkInWindow(for type: CheckInType) -> DateInterval? {
        let calendar = Calendar.current

        switch type {
        case .twentyFourHour:
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: self.date) else { return nil }
            return calendar.dateInterval(of: .day, for: nextDay)

        case .twoWeek:
            guard let targetDate = calendar.date(byAdding: .day, value: type.daysFromEpisode, to: self.date) else { return nil }
            let windowStart = calendar.startOfDay(for: targetDate)
            guard let windowEnd = calendar.date(byAdding: .hour, value: 24, to: windowStart) else { return nil }
            return DateInterval(start: windowStart, end: windowEnd)

        case .threeMonth:
            guard let targetDate = calendar.date(byAdding: .day, value: type.daysFromEpisode, to: self.date) else { return nil }
            let windowStart = calendar.startOfDay(for: targetDate)
            guard let windowEnd = calendar.date(byAdding: .day, value: 5, to: windowStart) else { return nil }
            return DateInterval(start: windowStart, end: windowEnd)
        }
    }

    func isCheckInWindowActive(for type: CheckInType) -> Bool {
        guard let window = checkInWindow(for: type) else { return false }
        return window.contains(Date())
    }
    
    func hasCheckIn(for type: CheckInType) -> Bool {
        return checkIns.contains { $0.checkInType == type }
    }
    
    func checkIn(for type: CheckInType) -> CheckIn? {
        return checkIns.first { $0.checkInType == type }
    }
    
    func dismissCheckIn(for type: CheckInType) {
        if !dismissedCheckIns.contains(type.rawValue) {
            dismissedCheckIns.append(type.rawValue)
        }
    }
    
    func isCheckInDismissed(for type: CheckInType) -> Bool {
        return dismissedCheckIns.contains(type.rawValue)
    }
    
    // Check-in types whose window is currently active and that haven't been
    // completed or dismissed. Single source of truth for badges, dots, and
    // the pending check-in cards.
    var pendingCheckInTypes: [CheckInType] {
        CheckInType.allCases.filter { type in
            isCheckInWindowActive(for: type) && !hasCheckIn(for: type) && !isCheckInDismissed(for: type)
        }
    }

    var hasPendingCheckIn: Bool {
        !pendingCheckInTypes.isEmpty
    }
    
    // Notification management methods
    func scheduleNotifications() {
        let ids = NotificationManager.shared.scheduleCheckInNotifications(for: self)
        self.notificationIDs = ids
    }

    // Re-schedule the notification for a single check-in type (e.g. after its
    // check-in was deleted), leaving other pending notifications untouched.
    func rescheduleNotification(for checkInType: CheckInType) {
        if let id = NotificationManager.shared.scheduleCheckInNotification(for: self, checkInType: checkInType) {
            notificationIDs.append(id)
        }
    }
    
    func cancelAllNotifications() {
        // Use the stored notification IDs that were returned when scheduling
        // rather than regenerating them, since persistentModelID string representation
        // can differ between scheduling and cancellation
        if !notificationIDs.isEmpty {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: notificationIDs)
            print("🗑️ Cancelled \(notificationIDs.count) notifications using stored IDs")
        }
        self.notificationIDs = []
    }
    
    func cancelNotificationForCheckIn(_ checkInType: CheckInType) {
        // Cancel via the stored IDs rather than regenerating them; the suffix
        // match also covers IDs created before the UUID-based format
        let ids = notificationIDs.filter { $0.hasSuffix("_\(checkInType.rawValue)") }
        guard !ids.isEmpty else { return }

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        notificationIDs.removeAll { ids.contains($0) }
        print("🗑️ Cancelled \(checkInType.displayName) notification using stored IDs")
    }
}

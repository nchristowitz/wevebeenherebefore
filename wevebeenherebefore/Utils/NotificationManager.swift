import Foundation
import SwiftData
import UserNotifications

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private init() {}
    
    @Published var hasPermission = false
    
    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            
            await MainActor.run {
                hasPermission = granted
            }
            
            if granted {
                print("✅ Notification permission granted")
            } else {
                print("❌ Notification permission denied")
            }
        } catch {
            print("❌ Notification permission error: \(error)")
        }
    }
    
    func checkPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            hasPermission = settings.authorizationStatus == .authorized
        }
        print("📱 Current notification permission: \(settings.authorizationStatus.rawValue)")
    }
    
    func scheduleCheckInNotifications(for episode: Episode) -> [String] {
        print("🔔 Starting notification scheduling for episode: \(episode.title)")
        print("📱 Permission status: \(hasPermission)")
        
        guard hasPermission else {
            print("❌ Cannot schedule notifications: Permission not granted")
            return []
        }
        
        var notificationIDs: [String] = []
        
        for checkInType in CheckInType.allCases {
            print("📅 Attempting to schedule \(checkInType.displayName) notification...")
            if let notificationID = scheduleNotification(for: episode, checkInType: checkInType) {
                notificationIDs.append(notificationID)
                print("✅ Successfully scheduled notification for \(checkInType.displayName) with ID: \(notificationID)")
            } else {
                print("❌ Failed to schedule notification for \(checkInType.displayName)")
            }
        }
        
        print("📊 Total notifications scheduled: \(notificationIDs.count)/\(CheckInType.allCases.count)")
        return notificationIDs
    }

    // Schedule the notification for a single check-in type. Returns the
    // notification ID, or nil if permission is missing or the date has passed.
    func scheduleCheckInNotification(for episode: Episode, checkInType: CheckInType) -> String? {
        guard hasPermission else {
            print("❌ Cannot schedule notification: Permission not granted")
            return nil
        }
        return scheduleNotification(for: episode, checkInType: checkInType)
    }

    // Recalculate the app badge from actual pending check-ins and clear
    // delivered notifications. Call whenever pending state may have changed.
    func refreshBadgeCount(modelContext: ModelContext) {
        let episodes = (try? modelContext.fetch(FetchDescriptor<Episode>())) ?? []
        let pendingCount = episodes.reduce(0) { $0 + $1.pendingCheckInTypes.count }

        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().setBadgeCount(pendingCount)
        print("📱 Updated badge count to: \(pendingCount)")
    }

    private func scheduleNotification(for episode: Episode, checkInType: CheckInType) -> String? {
        // Built from the episode's stable UUID — persistentModelID changes
        // between its temporary and permanent form and must not be used here
        let notificationID = "\(episode.uuid.uuidString)_\(checkInType.rawValue)"
        
        // Calculate notification date
        guard let notificationDate = calculateNotificationDate(for: episode, checkInType: checkInType) else {
            print("❌ Could not calculate notification date for \(checkInType.displayName)")
            return nil
        }
        
        // Check if the notification date is in the future
        let now = Date()
        if notificationDate <= now {
            print("⚠️ Notification date (\(notificationDate)) is in the past for \(checkInType.displayName)")
            return nil
        }
        
        print("📅 Scheduling \(checkInType.displayName) notification for: \(notificationDate)")
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Episode Check-in"
        content.body = notificationMessage(for: checkInType, episodeTitle: episode.title)
        content.sound = .default
        content.categoryIdentifier = "EPISODE_CHECKIN"
        // Badge will be set by the notification when it fires - iOS will increment automatically
        content.badge = NSNumber(value: 1)
        
        // Add episode data for when notification is tapped
        content.userInfo = [
            "episodeID": episode.uuid.uuidString,
            "checkInType": checkInType.rawValue
        ]


        // Create trigger
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: notificationID,
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling notification: \(error)")
            } else {
                print("✅ Successfully scheduled notification with ID: \(notificationID)")
            }
        }
        
        return notificationID
    }
    
    private func calculateNotificationDate(for episode: Episode, checkInType: CheckInType) -> Date? {
        let calendar = Calendar.current
        let notificationHour = UserDefaults.standard.object(forKey: "notificationHour") as? Int ?? 9
        let notificationMinute = UserDefaults.standard.object(forKey: "notificationMinute") as? Int ?? 0
        let now = Date()
        
        switch checkInType {
        case .twentyFourHour:
            // Day after episode at 9 AM
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: episode.date) else {
                print("❌ Could not calculate next day for 24h check-in")
                return nil
            }
            let notificationDate = calendar.date(bySettingHour: notificationHour, minute: notificationMinute, second: 0, of: nextDay)
            
            // If the calculated date is in the past, schedule for tomorrow at 9 AM instead
            if let date = notificationDate, date <= now {
                print("⚠️ 24h notification would be in past, scheduling for next available time")
                return calendar.date(byAdding: .day, value: 1, to: now)?.setting(hour: notificationHour, minute: notificationMinute)
            }
            
            return notificationDate
            
        case .twoWeek:
            // 2 weeks after episode at 9 AM
            guard let targetDate = calendar.date(byAdding: .day, value: 14, to: episode.date) else {
                print("❌ Could not calculate 2-week date")
                return nil
            }
            return calendar.date(bySettingHour: notificationHour, minute: notificationMinute, second: 0, of: targetDate)

        case .threeMonth:
            // 3 months after episode at 9 AM
            guard let targetDate = calendar.date(byAdding: .day, value: 90, to: episode.date) else {
                print("❌ Could not calculate 3-month date")
                return nil
            }
            return calendar.date(bySettingHour: notificationHour, minute: notificationMinute, second: 0, of: targetDate)
        }
    }
    
    private func notificationMessage(for checkInType: CheckInType, episodeTitle: String) -> String {
        switch checkInType {
        case .twentyFourHour:
            return "How are you feeling today? Yesterday's episode check-in is ready."
        case .twoWeek:
            return "2-week check-in: How do you feel about \"\(episodeTitle)\" now?"
        case .threeMonth:
            return "3-month perspective: Time to reflect on \"\(episodeTitle)\""
        }
    }
    
    // One-time migration to UUID-based notification identifiers. Episodes
    // created before the uuid field have pending notifications whose userInfo
    // carries a stale persistentModelID string that deep-linking can't match.
    // Cancel them via the stored IDs (always reliable) and re-schedule the
    // still-relevant ones with UUID-based IDs.
    // @MainActor is load-bearing: callers pass the container's mainContext,
    // and without it an await from a SwiftUI .task hops this function onto a
    // background executor — using that context off-main crashes in save().
    @MainActor
    func migrateNotificationsToUUIDIfNeeded(modelContext: ModelContext) async {
        let migrationKey = "didMigrateNotificationsToUUID"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        await checkPermission()
        guard hasPermission else {
            // Nothing can be scheduled without permission; retry next launch
            return
        }

        let episodes = (try? modelContext.fetch(FetchDescriptor<Episode>())) ?? []

        for episode in episodes {
            if !episode.notificationIDs.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: episode.notificationIDs)
            }

            // Re-schedule only check-ins that are still ahead of the user;
            // scheduleNotification itself skips dates already in the past
            episode.notificationIDs = CheckInType.allCases.compactMap { type in
                guard !episode.hasCheckIn(for: type), !episode.isCheckInDismissed(for: type) else { return nil }
                return scheduleNotification(for: episode, checkInType: type)
            }
        }

        do {
            try modelContext.save()
            UserDefaults.standard.set(true, forKey: migrationKey)
            print("✅ Migrated notifications to UUID-based IDs for \(episodes.count) episodes")
        } catch {
            print("❌ Notification migration failed to save: \(error)")
        }
    }

}


// Helper extension for setting date components
extension Date {
    func setting(hour: Int, minute: Int) -> Date? {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: self)
    }
}

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
    
    // The reminder goes out at the user's chosen time on the day the
    // check-in window opens — the same window (Episode.checkInWindow) the
    // in-app cards use. If that moment has passed, scheduleNotification skips it.
    private func calculateNotificationDate(for episode: Episode, checkInType: CheckInType) -> Date? {
        guard let window = episode.checkInWindow(for: checkInType) else {
            print("❌ Could not calculate the \(checkInType.displayName) window")
            return nil
        }

        let notificationHour = UserDefaults.standard.object(forKey: "notificationHour") as? Int ?? 9
        let notificationMinute = UserDefaults.standard.object(forKey: "notificationMinute") as? Int ?? 0
        return Calendar.current.date(bySettingHour: notificationHour, minute: notificationMinute, second: 0, of: window.start)
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

        rescheduleAllNotifications(modelContext: modelContext)

        do {
            try modelContext.save()
            UserDefaults.standard.set(true, forKey: migrationKey)
            print("✅ Migrated notifications to UUID-based IDs")
        } catch {
            print("❌ Notification migration failed to save: \(error)")
        }
    }

    // Called when the reminder time changes in Settings. Already-scheduled
    // reminders carry the old time, so cancel and re-schedule them all.
    @MainActor
    func rescheduleForNewReminderTime(modelContext: ModelContext) async {
        await checkPermission()
        guard hasPermission else { return }

        rescheduleAllNotifications(modelContext: modelContext)

        do {
            try modelContext.save()
            print("✅ Re-scheduled reminders for the new reminder time")
        } catch {
            print("❌ Failed to save re-scheduled reminders: \(error)")
        }
    }

    // Cancel every episode's pending reminders via the stored IDs, then
    // re-schedule the ones still ahead. Callers save the context and must
    // have checked permission.
    @MainActor
    private func rescheduleAllNotifications(modelContext: ModelContext) {
        let episodes = (try? modelContext.fetch(FetchDescriptor<Episode>())) ?? []

        for episode in episodes {
            if !episode.notificationIDs.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: episode.notificationIDs)
            }

            episode.notificationIDs = scheduleRemainingNotifications(for: episode)
        }
    }

    // Schedule reminders for an episode's check-ins that are still ahead:
    // not completed, not dismissed, and (checked in scheduleNotification)
    // not in the past. Returns the scheduled IDs to store on the episode.
    // Callers must have checked permission.
    func scheduleRemainingNotifications(for episode: Episode) -> [String] {
        CheckInType.allCases.compactMap { type in
            guard !episode.hasCheckIn(for: type), !episode.isCheckInDismissed(for: type) else { return nil }
            return scheduleNotification(for: episode, checkInType: type)
        }
    }

}

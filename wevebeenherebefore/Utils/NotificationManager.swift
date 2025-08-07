import Foundation
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
    
    private func scheduleNotification(for episode: Episode, checkInType: CheckInType) -> String? {
        let notificationID = "\(episode.persistentModelID)_\(checkInType.rawValue)"
        
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
        content.badge = 1
        
        // Add episode data for when notification is tapped
        // Store the persistent ID as a string - SwiftData will handle the lookup
        let episodeIDString = "\(episode.persistentModelID)"
        
        content.userInfo = [
            "episodeID": episodeIDString,
            "checkInType": checkInType.rawValue
        ]
        
        print("🔍 Storing episodeID in notification: '\(episodeIDString)'")
        
        
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
        let notificationHour = 9 // 9 AM
        let now = Date()
        
        switch checkInType {
        case .twentyFourHour:
            // Day after episode at 9 AM
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: episode.date) else {
                print("❌ Could not calculate next day for 24h check-in")
                return nil
            }
            let notificationDate = calendar.date(bySettingHour: notificationHour, minute: 0, second: 0, of: nextDay)
            
            // If the calculated date is in the past, schedule for tomorrow at 9 AM instead
            if let date = notificationDate, date <= now {
                print("⚠️ 24h notification would be in past, scheduling for next available time")
                return calendar.date(byAdding: .day, value: 1, to: now)?.setting(hour: notificationHour, minute: 0)
            }
            
            return notificationDate
            
        case .twoWeek:
            // 2 weeks after episode at 9 AM
            guard let targetDate = calendar.date(byAdding: .day, value: 14, to: episode.date) else {
                print("❌ Could not calculate 2-week date")
                return nil
            }
            return calendar.date(bySettingHour: notificationHour, minute: 0, second: 0, of: targetDate)
            
        case .threeMonth:
            // 3 months after episode at 9 AM
            guard let targetDate = calendar.date(byAdding: .day, value: 90, to: episode.date) else {
                print("❌ Could not calculate 3-month date")
                return nil
            }
            return calendar.date(bySettingHour: notificationHour, minute: 0, second: 0, of: targetDate)
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
    
    func cancelNotification(with id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        print("🗑️ Cancelled notification with ID: \(id)")
    }
    
    func cancelAllNotifications(for episode: Episode) {
        let notificationIDs = CheckInType.allCases.map { "\(episode.persistentModelID)_\($0.rawValue)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: notificationIDs)
        print("🗑️ Cancelled all notifications for episode: \(episode.title)")
    }
    
    func cancelNotificationForCheckIn(episode: Episode, checkInType: CheckInType) {
        let notificationID = "\(episode.persistentModelID)_\(checkInType.rawValue)"
        cancelNotification(with: notificationID)
    }
    
    // Debug function to check pending notifications
    func debugPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("📋 Total pending notifications: \(requests.count)")
            for request in requests {
                if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                    let components = trigger.dateComponents
                    print("📅 Pending: \(request.identifier) - \(components)")
                }
            }
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

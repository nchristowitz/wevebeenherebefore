import Foundation
import UserNotifications

/// Represents navigation data for a check-in that was triggered from a
/// notification tap.
struct CheckInNavigation: Identifiable {
    let episodeID: String
    let checkInType: CheckInType

    var id: String { "\(episodeID)_\(checkInType.rawValue)" }
}

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    private init() {}

    @Published var hasPermission = false
    // Stores information about a notification that the user tapped so the app
    // can navigate to the correct check-in screen.
    @Published var pendingCheckIn: CheckInNavigation?
    
    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            
            await MainActor.run {
                hasPermission = granted
            }
        } catch {
            print("Notification permission error: \(error)")
        }
    }
    
    func checkPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            hasPermission = settings.authorizationStatus == .authorized
        }
    }

    /// Called by the `AppDelegate` when a notification is tapped. Stores the
    /// episode and check‑in information so that the UI can navigate to the
    /// appropriate screen.
    func handleNotificationResponse(_ response: UNNotificationResponse) {
        let info = response.notification.request.content.userInfo
        guard let episodeID = info["episodeID"] as? String,
              let rawType = info["checkInType"] as? String,
              let type = CheckInType(rawValue: rawType) else {
            return
        }

        DispatchQueue.main.async {
            self.pendingCheckIn = CheckInNavigation(episodeID: episodeID, checkInType: type)
        }
    }
    
    func scheduleCheckInNotifications(for episode: Episode) -> [String] {
        guard hasPermission else { return [] }
        
        var notificationIDs: [String] = []
        
        for checkInType in CheckInType.allCases {
            let notificationID = scheduleNotification(for: episode, checkInType: checkInType)
            if let id = notificationID {
                notificationIDs.append(id)
            }
        }
        
        return notificationIDs
    }
    
    private func scheduleNotification(for episode: Episode, checkInType: CheckInType) -> String? {
        let notificationID = "\(episode.persistentModelID)_\(checkInType.rawValue)"
        
        // Calculate notification date
        guard let notificationDate = calculateNotificationDate(for: episode, checkInType: checkInType) else {
            return nil
        }
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Episode Check-in"
        content.body = notificationMessage(for: checkInType, episodeTitle: episode.title)
        content.sound = .default
        content.categoryIdentifier = "EPISODE_CHECKIN"
        
        // Add episode data for when notification is tapped
        content.userInfo = [
            "episodeID": "\(episode.persistentModelID)",
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
                print("Error scheduling notification: \(error)")
            }
        }
        
        return notificationID
    }
    
    private func calculateNotificationDate(for episode: Episode, checkInType: CheckInType) -> Date? {
        let calendar = Calendar.current
        let notificationHour = 9 // 9 AM
        
        switch checkInType {
        case .twentyFourHour:
            // Day after episode at 9 AM
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: episode.date) else { return nil }
            return calendar.date(bySettingHour: notificationHour, minute: 0, second: 0, of: nextDay)
            
        case .twoWeek:
            // 2 weeks after episode at 9 AM
            guard let targetDate = calendar.date(byAdding: .day, value: 14, to: episode.date) else { return nil }
            return calendar.date(bySettingHour: notificationHour, minute: 0, second: 0, of: targetDate)
            
        case .threeMonth:
            // 3 months after episode at 9 AM
            guard let targetDate = calendar.date(byAdding: .day, value: 90, to: episode.date) else { return nil }
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
    }
    
    func cancelAllNotifications(for episode: Episode) {
        let notificationIDs = CheckInType.allCases.map { "\(episode.persistentModelID)_\($0.rawValue)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: notificationIDs)
    }
    
    func cancelNotificationForCheckIn(episode: Episode, checkInType: CheckInType) {
        let notificationID = "\(episode.persistentModelID)_\(checkInType.rawValue)"
        cancelNotification(with: notificationID)
    }
}

import SwiftUI
import SwiftData

@Model
final class Episode {
    var title: String
    var date: Date
    var emotions: [String: Int] // Store emotion name and rating
    var prompts: [String: String] // Store prompt title and response
    var createdAt: Date
    var notificationIDs: [String] = [] // Store notification IDs for cleanup
    
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
    
    // Helper methods for check-in logic
    func isCheckInWindowActive(for type: CheckInType) -> Bool {
        let now = Date()
        let calendar = Calendar.current
        
        switch type {
        case .twentyFourHour:
            // Available starting the day after the episode (regardless of time)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: self.date),
                  let startOfNextDay = calendar.dateInterval(of: .day, for: nextDay)?.start,
                  let endOfNextDay = calendar.dateInterval(of: .day, for: nextDay)?.end else { return false }
            return now >= startOfNextDay && now < endOfNextDay
            
        case .twoWeek:
            let targetDate = calendar.date(byAdding: .day, value: type.daysFromEpisode, to: self.date) ?? self.date
            let windowStart = calendar.startOfDay(for: targetDate)
            let windowEnd = calendar.date(byAdding: .hour, value: 24, to: windowStart) ?? windowStart
            return now >= windowStart && now <= windowEnd
            
        case .threeMonth:
            let targetDate = calendar.date(byAdding: .day, value: type.daysFromEpisode, to: self.date) ?? self.date
            let windowStart = calendar.startOfDay(for: targetDate)
            let windowEnd = calendar.date(byAdding: .hour, value: 24, to: windowStart) ?? windowStart
            return now >= windowStart && now <= windowEnd
        }
    }
    
    func hasCheckIn(for type: CheckInType) -> Bool {
        return checkIns.contains { $0.checkInType == type }
    }
    
    func checkIn(for type: CheckInType) -> CheckIn? {
        return checkIns.first { $0.checkInType == type }
    }
    
    // Returns true if any check-in window is currently active and the check-in
       // hasn't been completed yet.
       var hasPendingCheckIn: Bool {
           for type in CheckInType.allCases {
               if isCheckInWindowActive(for: type) && !hasCheckIn(for: type) {
                   return true
               }
           }
           return false
       }
    
    // Notification management methods
    func scheduleNotifications() {
        let ids = NotificationManager.shared.scheduleCheckInNotifications(for: self)
        self.notificationIDs = ids
    }
    
    func cancelAllNotifications() {
        NotificationManager.shared.cancelAllNotifications(for: self)
        self.notificationIDs = []
    }
    
    func cancelNotificationForCheckIn(_ checkInType: CheckInType) {
        NotificationManager.shared.cancelNotificationForCheckIn(episode: self, checkInType: checkInType)
        // Remove the specific notification ID from our list
        let notificationID = "\(self.persistentModelID)_\(checkInType.rawValue)"
        notificationIDs.removeAll { $0 == notificationID }
    }
}

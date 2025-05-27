import SwiftUI
import SwiftData

@Model
final class Episode {
    var title: String
    var date: Date
    var emotions: [String: Int] // Store emotion name and rating
    var prompts: [String: String] // Store prompt title and response
    var createdAt: Date
    
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
            let windowEnd = calendar.date(byAdding: .hour, value: 24, to: targetDate) ?? targetDate
            return now >= targetDate && now <= windowEnd
            
        case .threeMonth:
            let targetDate = calendar.date(byAdding: .day, value: type.daysFromEpisode, to: self.date) ?? self.date
            let windowEnd = calendar.date(byAdding: .hour, value: 24, to: targetDate) ?? targetDate
            return now >= targetDate && now <= windowEnd
        }
    }
    
    func hasCheckIn(for type: CheckInType) -> Bool {
        return checkIns.contains { $0.checkInType == type }
    }
    
    func checkIn(for type: CheckInType) -> CheckIn? {
        return checkIns.first { $0.checkInType == type }
    }
}

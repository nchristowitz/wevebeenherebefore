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
        let targetDate = Calendar.current.date(byAdding: .day, value: type.daysFromEpisode, to: self.date) ?? self.date
        let now = Date()
        let windowEnd = Calendar.current.date(byAdding: .hour, value: 24, to: targetDate) ?? targetDate
        
        return now >= targetDate && now <= windowEnd
    }
    
    func hasCheckIn(for type: CheckInType) -> Bool {
        return checkIns.contains { $0.checkInType == type }
    }
    
    func checkIn(for type: CheckInType) -> CheckIn? {
        return checkIns.first { $0.checkInType == type }
    }
}

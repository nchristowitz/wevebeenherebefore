import SwiftUI
import SwiftData

enum CheckInType: String, Codable, CaseIterable, Identifiable {
    case twentyFourHour = "24h"
    case twoWeek = "2w"
    case threeMonth = "3m"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .twentyFourHour:
            return "24 Hour Check-in"
        case .twoWeek:
            return "2 Week Check-in"
        case .threeMonth:
            return "3 Month Check-in"
        }
    }
    
    var daysFromEpisode: Int {
        switch self {
        case .twentyFourHour:
            return 1
        case .twoWeek:
            return 14
        case .threeMonth:
            return 90 // Approximately 3 months
        }
    }
}

@Model
final class CheckIn {
    var text: String
    var checkInType: CheckInType
    var createdAt: Date
    var episode: Episode?
    
    init(text: String, checkInType: CheckInType, episode: Episode) {
        self.text = text
        self.checkInType = checkInType
        self.createdAt = Date()
        self.episode = episode
    }
}

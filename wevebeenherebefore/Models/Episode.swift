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
    
    init(title: String, emotions: [String: Int], prompts: [String: String]) {
        self.title = title
        self.date = Date()
        self.emotions = emotions
        self.prompts = prompts
        self.createdAt = Date()
    }
}

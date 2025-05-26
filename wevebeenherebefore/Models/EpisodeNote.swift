import SwiftUI
import SwiftData

@Model
final class EpisodeNote {
    var text: String
    var createdAt: Date
    var episode: Episode?
    
    init(text: String, episode: Episode) {
        self.text = text
        self.createdAt = Date()
        self.episode = episode
    }
}
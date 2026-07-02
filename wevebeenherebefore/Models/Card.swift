import SwiftUI
import SwiftData

enum CardType: String, Codable {
    case memory
    case delight
    case technique
}

// An Apple Music song attached to a card. persistentID is the device
// library identifier used for playback; storeID is the catalog ID kept
// as a portable fallback. Title/artist/artwork are stored so the card
// renders without touching the media library.
struct CardSong: Equatable {
    var persistentID: String
    var storeID: String?
    var title: String
    var artist: String
    var artworkData: Data?
}

@Model
final class Card {
    var text: String
    var type: CardType
    var colorRed: Double
    var colorGreen: Double
    var colorBlue: Double
    var date: Date?   // Optional: only used for memories
    var imageData: Data?  // Optional: only used for delights
    var createdAt: Date

    // Song attachment, flattened for SwiftData (all optional so existing
    // stores migrate in place). Used for delights and memories.
    var songPersistentID: String?
    var songStoreID: String?
    var songTitle: String?
    var songArtist: String?
    var songArtworkData: Data?

    var song: CardSong? {
        get {
            guard let persistentID = songPersistentID, let title = songTitle else { return nil }
            return CardSong(
                persistentID: persistentID,
                storeID: songStoreID,
                title: title,
                artist: songArtist ?? "",
                artworkData: songArtworkData
            )
        }
        set {
            songPersistentID = newValue?.persistentID
            songStoreID = newValue?.storeID
            songTitle = newValue?.title
            songArtist = newValue?.artist
            songArtworkData = newValue?.artworkData
        }
    }
    
    // Remove @Attribute and make it computed without storage
    var color: Color {
        get {
            Color(.sRGB, red: colorRed, green: colorGreen, blue: colorBlue, opacity: 1)
        }
        set {
            if let components = UIColor(newValue).cgColor.components {
                colorRed = Double(components[0])
                colorGreen = Double(components[1])
                colorBlue = Double(components[2])
            }
        }
    }
    
    init(text: String, type: CardType, color: Color, date: Date? = nil, imageData: Data? = nil, song: CardSong? = nil) {
        self.text = text
        self.type = type
        self.colorRed = 0
        self.colorGreen = 0
        self.colorBlue = 0
        self.date = date
        self.imageData = imageData
        self.createdAt = Date()
        self.color = color // This will set the RGB components
        self.song = song
    }
} 
import SwiftUI
import SwiftData
import ImageIO

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
    
    // Computed from the stored RGB values
    var color: Color {
        get {
            Color(.sRGB, red: colorRed, green: colorGreen, blue: colorBlue, opacity: 1)
        }
        set {
            let rgb = newValue.sRGBComponents
            colorRed = rgb.red
            colorGreen = rgb.green
            colorBlue = rgb.blue
        }
    }

    // Color for new cards: the light-mode value of systemGray6. Fixed rather
    // than the adaptive system color, which would be stored as near-black
    // if a card were created in Dark Mode. Dark Mode shows its dark version.
    static let defaultColor = Color(uiColor: UIColor.systemGray6.resolvedColor(
        with: UITraitCollection(userInterfaceStyle: .light)
    ))

    // Longest edge, in pixels, for stored card photos — sharp on any
    // iPhone screen while keeping the database and backups small
    static let maxImagePixelSize = 2048

    // Re-encode a photo as a JPEG no larger than maxImagePixelSize, keeping
    // its orientation. Returns nil when the photo is already small enough
    // or can't be read, so callers keep the original.
    static func downscaledImageData(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              max(width, height) > maxImagePixelSize else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxImagePixelSize
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: image).jpegData(compressionQuality: 0.85)
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
import SwiftUI
import SwiftData

enum CardType: String, Codable {
    case memory
    case delight
    case technique
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
    
    init(text: String, type: CardType, color: Color, date: Date? = nil, imageData: Data? = nil) {
        self.text = text
        self.type = type
        self.colorRed = 0
        self.colorGreen = 0
        self.colorBlue = 0
        self.date = date
        self.imageData = imageData
        self.createdAt = Date()
        self.color = color // This will set the RGB components
    }
} 
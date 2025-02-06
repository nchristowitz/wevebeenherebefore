import SwiftUI

enum AppConfig {
    static let cardColors: [CardType: Color] = [
        .memory: .pink.opacity(0.3),
        .delight: .yellow.opacity(0.3),
        .technique: .purple.opacity(0.3)
    ]
    
    static let cardPlaceholders: [CardType: String] = [
        .memory: "Briefly describe a memory that shows your resilience. E.g. I overcame my fear of failure and learned German.",
        .delight: "Keep the delight short and sweet. E.g. The way my cat's fur feels under his neck.",
        .technique: "What helps you in moments like this? E.g. Go for a long coffee walk"
    ]
} 
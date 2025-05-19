import SwiftUI

enum AppConfig {
    // DESIGN PRINCIPLES:
    // 1. Keep the app simple and focused on personal well-being
    // 2. Use SwiftUI and native iOS interactions wherever possible
    // 3. Prioritize a clean, calming user experience over complex features
    // 4. Build for personal resilience - memories, delights, and techniques form a toolkit
    //    to help navigate through difficult emotional episodes
    
    static let designPrinciples = """
    We've Been Here Before - Design Principles
    
    1. Simplicity First: Use SwiftUI and native iOS interactions rather than custom solutions
    2. Focus on Resilience: Every feature should contribute to building personal emotional resilience
    3. User-Centered: The app is a personal tool - optimize for individual use and reflection
    4. Calm Experience: UI choices should promote a sense of calm and clarity
    5. Toolkit Approach: Memories, delights, and techniques form a practical toolkit for difficult moments
    """
    
    static let cardPlaceholders: [CardType: String] = [
        .memory: "Briefly describe a memory that shows your resilience. E.g. I overcame my fear of failure and learned German.",
        .delight: "Keep the delight short and sweet. E.g. The way my cat's fur feels under his neck.",
        .technique: "What helps you in moments like this? E.g. Go for a long coffee walk"
    ]
}
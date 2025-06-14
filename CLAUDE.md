# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"We've Been Here Before" is a SwiftUI iOS app focused on building personal emotional resilience. The app helps users create a toolkit of memories, delights, and techniques to navigate difficult emotional episodes, with a structured follow-up system through timed check-ins.

## Core Architecture

### Data Models (SwiftData)
- **Card**: Resilience cards with three types (memory, delight, technique), each with text, color, optional date/image, stored using SwiftData
- **Episode**: Emotional episodes with emotion ratings, prompt responses, and relationships to notes/check-ins
- **CheckIn**: Follow-up reflections tied to episodes at specific intervals (24h, 2w, 3m)
- **EpisodeNote**: Additional notes that can be added to episodes

### Navigation & State Management
- **ResilienceView**: Main view with card list, filtering, and navigation to different flows
- **NotificationCoordinator**: Singleton managing deep linking from notifications to check-in flows
- **EpisodeFlowState**: ObservableObject managing the multi-step episode creation flow

### Notification System
- **NotificationManager**: Handles permission requests and scheduling check-in notifications
- **AppDelegate**: Manages notification handling, badge updates, and deep linking
- Notifications are scheduled for 24h, 2w, and 3m check-ins after episode creation

## Key Development Commands

### Building & Testing
```bash
# Build the project
xcodebuild -project wevebeenherebefore.xcodeproj -scheme wevebeenherebefore -destination 'platform=iOS Simulator,name=iPhone 15'

# Run tests
xcodebuild test -project wevebeenherebefore.xcodeproj -scheme wevebeenherebefore -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Simulator Testing
```bash
# Launch iOS Simulator
open -a Simulator

# Install app on simulator
xcodebuild -project wevebeenherebefore.xcodeproj -scheme wevebeenherebefore -destination 'platform=iOS Simulator,name=iPhone 15' -derivedDataPath build
```

## Design Principles

The app follows specific design principles outlined in `AppConfig.swift`:
1. **Simplicity First**: Use SwiftUI and native iOS interactions
2. **Focus on Resilience**: Every feature should contribute to building emotional resilience
3. **User-Centered**: Optimize for individual use and personal reflection
4. **Calm Experience**: UI choices should promote calm and clarity  
5. **Toolkit Approach**: Cards form a practical toolkit for difficult moments

## Code Patterns

### SwiftData Usage
- All models use `@Model` macro for SwiftData persistence
- Relationships use `@Relationship(deleteRule: .cascade)` for proper cleanup
- Main model container configured in `wevebeenherebeforeApp.swift` with schema including all model types

### View Structure
- **MenuTray**: Reusable bottom-sliding menu component
- **CircularButton**: Consistent button styling throughout app
- **Sheet-based Navigation**: Most flows use `.sheet()` modifiers for modal presentation
- **Deep Linking**: Notification taps navigate to specific check-in views via NotificationCoordinator

### Color Management
- Cards store RGB values as separate Double properties (colorRed, colorGreen, colorBlue)
- Computed `color` property converts to/from SwiftUI Color
- `ColorUtils.swift` provides contrast text color calculations

### Notification Workflow
1. Episode creation triggers `scheduleNotifications()`
2. Notifications scheduled for each CheckInType with unique IDs
3. Notification taps handled by AppDelegate → NotificationCoordinator → ResilienceView
4. Badge count updates based on active check-in windows

## Testing Architecture

- Uses Swift Testing framework (not XCTest)
- Test files use `@testable import wevebeenherebefore`
- Minimal test coverage currently - mainly placeholder tests
- UI tests separate in `wevebeenherebeforeUITests/`

## File Organization

- `Models/`: SwiftData model definitions
- `Views/`: SwiftUI views organized by feature (Episode/, EmotionRating/, etc.)
- `Components/`: Reusable UI components
- `Utils/`: Utility classes (NotificationManager, ColorUtils, etc.)
- `Extensions/`: Swift extensions (directory exists but files not explored)

## Key Implementation Notes

- Episode check-in windows are calculated based on episode date + CheckInType.daysFromEpisode
- Notification IDs stored in Episode model for proper cleanup
- Badge count reflects active check-in windows that haven't been completed
- Card editing uses same views as creation with optional `existingCard` parameter
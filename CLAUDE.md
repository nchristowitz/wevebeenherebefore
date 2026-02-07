# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"We've Been Here Before" is a personal SwiftUI iOS app focused on building emotional resilience. The core philosophy is that when you're in a difficult emotional moment, it helps to remember that you've navigated similar struggles before and survived them.

The app helps users:
1. **Build a resilience toolkit** of memories, delights, and techniques
2. **Log emotional episodes** with guided prompts that encourage future-focused reflection
3. **Follow up with check-ins** at 24 hours, 2 weeks, and 3 months to see how perspective changes over time
4. **Summarize episodes** after 3 months to distill lessons learned
5. **Review past successes** during new difficult moments via the "Remember" flow

## App Philosophy

The app is built around the insight that emotional episodes feel overwhelming in the moment, but with time and distance, we often realize they weren't as catastrophic as feared. The prompts deliberately ask users to predict how they'll feel in the future, then check-ins let them compare reality to those predictions. Episode summaries capture the wisdom gained.

## Core Architecture

### Data Models (SwiftData)

- **Card**: Resilience cards with three types:
  - `memory`: Past experiences showing resilience (has optional date)
  - `delight`: Things that bring joy (has optional image)
  - `technique`: Coping strategies
  - All cards have text, color (stored as RGB doubles), and timestamps

- **Episode**: Emotional episodes containing:
  - `emotions`: Dictionary of emotion names to ratings (0-5)
  - `prompts`: Dictionary of prompt questions to user responses
  - `summary`: Optional reflection written after 3 months
  - `summaryCreatedAt`: When the summary was written
  - Relationships to notes and check-ins (cascade delete)

- **CheckIn**: Follow-up reflections at intervals:
  - `twentyFourHour`: Day after episode
  - `twoWeek`: 14 days after
  - `threeMonth`: 90 days after

- **EpisodeNote**: Additional notes users can add to episodes over time

### Navigation Structure

Three-tab interface (`MainTabView`):
1. **Episodes**: List of past episodes, create new episodes
2. **Resilience**: Card toolkit + pending check-ins, filter menu with shuffle toggle
3. **Settings**: Notification time, export/import, debug tools

### Key Flows

**Episode Creation Flow** (`EpisodeFlowCoordinator`):
1. Rate emotions (0-5 scale)
2. Answer guided prompts about the episode and future predictions
3. Review and save
4. **RememberView**: Carousel of past episode summaries (skipped if none exist)
5. **ResilienceRemindersView**: Carousel of random toolkit cards

**Episode Summary Flow**:
- Available 90 days after episode creation (`canAddSummary`)
- User writes a reflection on what they learned
- Can create a Memory card from the summary (pre-populates AddMemoryView)

### State Management

- **EpisodeFlowState**: ObservableObject for multi-step episode wizard
- **NotificationCoordinator**: Singleton for deep linking from notifications
- **NotificationManager**: Singleton for notification permissions and scheduling

## Design & Development Principles

### Code Principles

1. **Reuse existing patterns** - Before creating something new, look for existing components that solve similar problems (e.g., CheckInView pattern for AddSummaryView)
2. **Keep it simple** - Avoid over-engineering. The simplest solution that works is best
3. **Follow iOS conventions** - Use native SwiftUI patterns and iOS design language
4. **Minimal new files** - Prefer extending existing files over creating new ones unless there's clear separation of concerns

### UI Principles

1. **Calm experience** - UI should promote clarity, not add stress
2. **Consistent patterns** - Carousels use `TabView` with `.page` style, text input uses similar editor patterns throughout
3. **Native feel** - Use system materials (`.regularMaterial`, `.thickMaterial`), standard swipe actions, iOS 26 liquid glass when available
4. **Cards fill space** - In carousels, cards expand to fill available height. Photo-only cards fill edge-to-edge

### SwiftUI Patterns Used

- **Sheets for flows**: Modal presentation via `.sheet(item:)`
- **Enum-based sheet state**: Type-safe sheet management with `Identifiable` enums
- **TabView carousels**: Horizontal swiping with `.tabViewStyle(.page)`
- **Swipe actions**: Edit/delete with `.swipeActions()`, explicit `.tint()` colors
- **Material backgrounds**: `.regularMaterial`, `.thickMaterial` for cards and buttons
- **Contrasting text**: `color.contrastingTextColor()` for readable text on colored backgrounds

## Key Development Commands

```bash
# Build the project
xcodebuild -project wevebeenherebefore.xcodeproj -scheme wevebeenherebefore -destination 'platform=iOS Simulator,name=iPhone 15'

# Run tests
xcodebuild test -project wevebeenherebefore.xcodeproj -scheme wevebeenherebefore -destination 'platform=iOS Simulator,name=iPhone 15'
```

## File Organization

```
wevebeenherebefore/
├── Models/                 # SwiftData models (Card, Episode, CheckIn, EpisodeNote)
├── Views/
│   ├── Episode/            # Episode flow views (EpisodeFlowCoordinator, EpisodeSummaryView,
│   │                       #   RememberView, ResilienceRemindersView, CheckInView, AddSummaryView)
│   ├── AddCardBaseView     # Base view for card creation (accepts initialText for pre-population)
│   ├── AddMemoryView       # Memory card creation (accepts initialText)
│   ├── AddDelightView      # Delight card creation with photo picker
│   ├── AddTechniqueView    # Technique card creation
│   ├── ResilienceView      # Main toolkit view with cards and pending check-ins
│   ├── EpisodesListView    # List of all episodes
│   └── SettingsView        # App settings (notification time, export/import, debug)
├── Components/             # Reusable UI (CardTextEditor, CheckInCard, etc.)
├── Utils/                  # NotificationManager, NotificationCoordinator, ColorUtils
└── Extensions/             # Swift extensions
```

## Key Implementation Details

### Episode Summary Feature

- `Episode.canAddSummary`: True when 90+ days have passed since episode date
- `Episode.hasSummary`: True when summary exists and is non-empty
- Summary section appears in EpisodeSummaryView above Notes section
- "Create Memory" button inside summary container opens AddMemoryView with pre-populated text
- AddCardBaseView accepts `initialText` parameter for pre-population

### Carousel Views

- **RememberView**: Shows shuffled episode summaries in carousel, skipped if no summaries exist
- **ResilienceRemindersView**: Shows up to 4 random toolkit cards in carousel
- **CarouselCardView**: Handles both text cards and photo-only cards (photo-only fills container with `scaledToFill`)

### Notification System

1. Episode creation triggers `scheduleNotifications()`
2. Notifications scheduled at user-configured time (default 9 AM), stored in `@AppStorage("notificationHour")` and `@AppStorage("notificationMinute")`
3. Notification taps handled: AppDelegate → NotificationCoordinator → View navigation
4. Badge count reflects active uncompleted check-in windows

**Important**: When cancelling notifications (e.g., on episode deletion), always use the stored `notificationIDs` array on the Episode model rather than regenerating IDs from `persistentModelID`. The string representation of `persistentModelID` can differ between scheduling and cancellation, causing silent cancellation failures.

### User Settings (@AppStorage)

Settings are stored via `@AppStorage` for persistence:
- `notificationHour` / `notificationMinute`: When check-in reminders are sent
- `shuffleCardsEnabled`: Whether resilience cards appear in random order

### ResilienceView Card Ordering

- Default: newest to oldest (via `@Query` sort)
- Shuffle mode: When enabled via filter menu, cards are shuffled on each view appearance
- Shuffle order stored in `shuffledCardIDs` state, persists for session but refreshes on next app launch
- Type filters (memory/delight/technique) apply on top of the current ordering

### Color Management

- Cards store RGB as `colorRed`, `colorGreen`, `colorBlue` (Double 0.0-1.0)
- Computed `color` property converts to SwiftUI Color
- `Color.contrastingTextColor()` returns black or white based on brightness

## Testing Notes

- Uses Swift Testing framework (not XCTest)
- Test with `@testable import wevebeenherebefore`
- Minimal test coverage currently
- Manual testing on device recommended for notification and UI flows

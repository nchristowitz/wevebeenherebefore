# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

"We've Been Here Before" is a personal SwiftUI iOS app focused on building emotional resilience. The core philosophy is that when you're in a difficult emotional moment, it helps to remember that you've navigated similar struggles before and survived them.

The app is for one person (the developer) on their own iPhone. It targets **iOS 26+** — no fallbacks for older versions.

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
  - Delights and memories can carry an Apple Music song (flattened `song*` fields)

- **Episode**: Emotional episodes containing:
  - `uuid`: Stable identity used for notifications and import de-duplication
  - `emotions`: Dictionary of emotion names to ratings (0-5)
  - `prompts`: Dictionary of prompt question wording to user responses
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
1. **Episodes**: Open check-in cards at the top, then past episodes grouped by year and month; create new episodes. The tab badge counts open check-ins.
2. **Resilience**: Card toolkit, filter menu with shuffle toggle
3. **Settings**: Notification time, export/import, debug tools

### Key Flows

**Episode Creation Flow** (`EpisodeFlowCoordinator`):
1. Rate emotions (0-5 scale)
2. Answer guided prompts about the episode and future predictions
3. Review and save — Back returns to the title prompt with all answers kept
4. **RememberView**: Carousel of past summaries and prediction-vs-reality pairs (skipped if none exist)
5. **ResilienceRemindersView**: Carousel of random toolkit cards

**Check-in Flow** (`CheckInView`):
- The prediction for that horizon shows at the top, blurred ("sealed") so it doesn't anchor what the user writes; tapping unseals it early
- Saving shows the verdict screen (`PredictionRealityCard`), revealing the prediction next to what was just written

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
3. **Native feel** - Use system materials (`.regularMaterial`, `.thickMaterial`), standard swipe actions, Liquid Glass (`.glassEffect()`)
4. **Cards fill space** - In carousels, cards expand to fill available height. Photo-only cards fill edge-to-edge
5. **The user's writing leads** - On the episode detail screen, answers are primary text; questions are small grey labels

### SwiftUI Patterns Used

- **Sheets for flows**: Modal presentation via `.sheet(item:)`, each sheet in its own `NavigationStack` (no `NavigationView`)
- **Enum-based sheet state**: Type-safe sheet management with `Identifiable` enums
- **TabView carousels**: Horizontal swiping with `.tabViewStyle(.page)`
- **Swipe actions**: Edit/delete with `.swipeActions()`, explicit `.tint()` colors. Delete buttons have no `role: .destructive` (that removes the row before confirming) and set a `...PendingDeletion` state that drives a confirmation `.alert`
- **Material backgrounds**: `.regularMaterial`, `.thickMaterial` for cards and buttons
- **Card colors**: `color.cardColor(for: colorScheme)` / `color.cardTextColor(for: colorScheme)` — never use a card's stored color directly for drawing
- **Save failures**: Editors call `modelContext.save()` explicitly; on failure they `rollback()`, keep the sheet open, and show `.saveErrorAlert($saveError)` (Components/SaveErrorAlert.swift)

## Key Development Commands

```bash
# Build the project
xcodebuild -project wevebeenherebefore.xcodeproj -scheme wevebeenherebefore -destination 'platform=iOS Simulator,name=iPhone 18 Pro'

# Run tests
xcodebuild test -project wevebeenherebefore.xcodeproj -scheme wevebeenherebefore -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```

Simulators must run iOS 26 or later.

## File Organization

```
wevebeenherebefore/
├── Models/                 # SwiftData models (Card, Episode, CheckIn, EpisodeNote)
├── Views/
│   ├── Episode/            # Episode flow views (EpisodeFlowCoordinator, EpisodePromptView,
│   │                       #   EpisodeSummaryView, RememberView, ResilienceRemindersView,
│   │                       #   CheckInView, AddSummaryView, EpisodesListView)
│   ├── EmotionRating/      # Emotion rating screen and the shared EmotionColor palette
│   ├── AddCardBaseView     # Base view for card creation (accepts initialText for pre-population)
│   ├── AddMemoryView       # Memory card creation (accepts initialText)
│   ├── AddDelightView      # Delight card creation with photo picker
│   ├── AddTechniqueView    # Technique card creation
│   ├── ResilienceView      # Main toolkit view with cards
│   └── SettingsView        # App settings (notification time, export/import, debug)
├── Components/             # Reusable UI (CardTextEditor, CheckInCard, SaveErrorAlert, etc.)
└── Utils/                  # NotificationManager, NotificationCoordinator, ColorUtils,
                            #   ExportManager, ImportManager
```

## Key Implementation Details

### Episode Prompts

- `EpisodePrompt.prompts` (EpisodePromptView.swift) is the single source of truth for the prompts, their order, and which check-in each prediction belongs to (`checkInType`)
- Answers are stored keyed by the question's wording at the time. **When rewording a question, add the old wording to its `earlierQuestions`** — that's how old episodes still find their predictions and display in order
- `EpisodePrompt.answeredPrompts(from:)` returns an episode's answers in prompt order for display; `Episode.prediction(for:)` finds a prediction under any wording
- `EpisodePrompt.titleQuestion` is the title prompt's key

### Check-in Timing

- `Episode.checkInWindow(for:)` is the single source of truth for when a check-in can be added: 24h = the calendar day after the episode, 2w = day 14, 3m = 5 days from day 90
- The pending cards, the episode detail screen, and reminder dates all derive from it

### Episode Summary Feature

- `Episode.canAddSummary`: True when 90+ days have passed since episode date
- `Episode.hasSummary`: True when summary exists and is non-empty
- Summary section appears in EpisodeSummaryView above Notes section
- "Create Memory" button inside summary container opens AddMemoryView with pre-populated text
- AddCardBaseView accepts `initialText` parameter for pre-population

### Carousel Views

- **RememberView**: Shows shuffled past summaries and prediction-vs-reality pairs, skipped if none exist
- **ResilienceRemindersView**: Shows up to 4 random toolkit cards in carousel
- **CarouselCardView**: Handles both text cards and photo-only cards (photo-only fills container with `scaledToFill`)
- Both are shown inside the coordinator's `NavigationStack` — don't wrap them in another one

### Notification System

1. Episode creation triggers scheduling; reminders go out at the user-configured time on the day each check-in window opens
2. Reminder time is stored in `@AppStorage("notificationHour")` and `@AppStorage("notificationMinute")`; changing it in Settings re-schedules all pending reminders (`rescheduleForNewReminderTime`)
3. `scheduleRemainingNotifications(for:)` schedules only check-ins still ahead (not done, not dismissed, not past) — used by rescheduling and import
4. Notification taps handled: AppDelegate → NotificationCoordinator → View navigation
5. Badge count reflects active uncompleted check-in windows, refreshed from `MainTabView` on launch and when the app becomes active

**Important**: When cancelling notifications (e.g., on episode deletion), always use the stored `notificationIDs` array on the Episode model rather than regenerating IDs from `persistentModelID`. The string representation of `persistentModelID` can differ between scheduling and cancellation, causing silent cancellation failures.

### Import / Export

- JSON is the only format that can be imported back; it includes photos and songs
- Import skips anything already in the app: episodes by `uuid` (or same title and creation time for old backups), cards by type, text and creation time
- Imported episodes get reminders for their remaining check-ins

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
- Computed `color` property converts to SwiftUI Color; the setter uses `Color.sRGBComponents`, which handles grayscale colors safely
- New cards default to `Card.defaultColor` (fixed light grey) — not an adaptive system color, which would be stored as near-black if created in Dark Mode
- `Color.contrastingTextColor()` returns black or white based on brightness

### Dark Mode

- Card colors (and the fixed check-in card colors) show as chosen in light mode and as `darkCardVariant` in Dark Mode: same hue in OKLCH, darkened so white text has at least 7:1 contrast (Apple's recommendation for custom colors). Tuning constants are in `ColorUtils.swift` (`DarkCard`)
- Stored colors are never changed — the dark version is computed for display
- Card photos use `.dimmedInDarkMode()` (12% darker in Dark Mode only), per Apple's guidance to slightly darken bright content images
- Debug Tools → "Add Cards in Sample Colors" seeds cards for checking both modes

### Photos

- Card photos are stored at most 2048 px on the longest edge (`Card.downscaledImageData`) — on pick and on import
- A one-time launch migration (`downscaleStoredCardPhotosIfNeeded`) shrank photos stored before this

## Testing Notes

- Uses Swift Testing framework (not XCTest) for unit tests; XCUIAutomation for UI tests
- Test with `@testable import wevebeenherebefore`
- Unit tests cover export/import round trips and de-duplication, check-in windows, UUIDs, prediction-vs-reality pairs, prompt order across wordings, colors, and photo downscaling
- `ExportImportRoundTripTests` is `.serialized`: export file names are only unique to the second, so parallel export tests would overwrite each other's file
- `UIRefreshScreenshotTests` walks the main screens and saves screenshots to /tmp/wbhb-screens; run on an erased simulator
- Manual testing on device recommended for notification and UI flows

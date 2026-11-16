# 2026 review

A review of the app after a year of personal use: data structures, flows and
visual design. It was written from reading the code only. Nothing here has
been checked against a running build, so the visual points in particular need
confirming in the simulator or in Previews before any of them is acted on.

Single-user app, so edge cases that the owner would never hit are left out.

## Worth fixing

1. **"Back" on the review step discards the episode.**
   `EpisodeSummaryView.swift:390` calls `dismiss()`. Nothing is pushed on the
   stack, so that closes the whole sheet with no confirmation.
2. **No back navigation or draft in the episode flow.** Steps are swapped in a
   `switch` (`EpisodeFlowCoordinator.swift:90`), so an earlier prompt can't be
   revisited. Responses live only in a `StateObject`; if the app is killed
   mid-flow they are gone.
3. **Swipe-to-delete on an episode is immediate.** A full swipe removes the
   episode with its check-ins, notes and summary (`EpisodesListView.swift:78`).
4. **Photos are stored at full resolution.** `AddDelightView.swift:55` saves the
   raw picker data. The Resilience list decodes it inside `body`
   (`ResilienceView.swift:409`) and JSON export base64-encodes all of it into
   one string (`ExportManager.swift:186`). Downscale on save.
5. **Changing the reminder time doesn't reschedule pending notifications**
   (`SettingsView.swift:16`).
6. **Missed check-ins can never be added.** The 2-week window is one day
   (`Episode.swift:77`). May be deliberate.
7. **Importing the same backup twice duplicates everything.**
   `ImportManager.swift:64` doesn't check existing episode UUIDs, and imported
   episodes get no notifications scheduled.

## Data structures

- **Prompts are keyed by question text.** Legacy wordings are listed in two
  places that disagree: `Episode.swift:103` knows "two weeks from now" and
  "What about 3 months from now?", `EpisodeSummaryView.swift:90` does not. An
  old episode with those wordings shows no check-in section in its detail
  view. Keep the storage; make `EpisodePrompt` the single source of keys.
- **Check-in window logic is duplicated.** `EpisodeSummaryView.swift:462-522`
  re-derives the windows differently from `Episode.checkInWindow(for:)`. It
  can leave an empty "2 Week Check-in" box the day after the window, or a
  disabled button reading "available now".
- **No schema versioning.** A failed migration hits `fatalError` at launch
  with no way to export. Keep model changes additive and export JSON first.
- **`notificationIDs` is redundant** now that IDs are derived from the UUID.

## Design suggestions

### Episode detail (`EpisodeSummaryView`)

- Answers render in secondary gray under large bold questions. Invert it: the
  question as a small label, the writing in primary.
- Use `PredictionRealityCard` and the orange / teal / indigo horizon colours
  from `CheckInCard` here.
- Replace the hardcoded blue buttons with 8pt corners. The rest of the app
  uses primary tint, glass and 20pt corners.
- Move Notes below the description. A new episode opens on an empty Notes
  section.
- One tint for the emotion bars instead of eight hues.
- Note and check-in rows have both `.contextMenu` and `.onLongPressGesture`
  (`:219-233`). Keep one.

### Episode flow

- Add a progress indicator ("3 of 7") and a back chevron.
- `RememberView` and `ResilienceRemindersView` each wrap their own
  `NavigationStack` inside the coordinator's. Check for an extra gap at the
  top of those two screens.
- The Remember carousel has no cap (`RememberView.swift:135`). Cap it at about
  five and prefer episodes sharing the current top emotion.

### Resilience

- The filter menu puts type filters, "Oldest First" and shuffle in one
  single-select state (`ResilienceView.swift:213-288`). A `Picker` for type
  plus a `Toggle` for shuffle would be native and shorter.
- Card text is 32pt regardless of length. Scale it by length.
- A memory created from a summary gets today's date, not the episode's
  (`EpisodeSummaryView.swift:420`).
- Check whether default-colour cards made in light mode look near-white in
  dark mode (`AddMemoryView.swift:16`). Unconfirmed.
- The pending-count badge sits on the Episodes tab; the actionable check-in
  cards are on Resilience.

### Editors

- The same text editor block is copied in five files
  (`EpisodePromptView`, `EpisodeTitlePromptView`, `CheckInView`,
  `AddSummaryView`, `CardTextEditor`).
- `AddNoteView` and `EditNoteView` use a different style (body text in a gray
  box) from the check-in and summary editors.

## Housekeeping

- Dead code: `Color.toHex`, `AppConfig.designPrinciples`,
  `FilterType.dateNewest`, `AddCardBaseView.placeholderText`.
- Filename typo: `Components/NotificaitonDot.swift`.
- Empty `explain` file at the repo root.
- `CLAUDE.md` predates songs and the prediction / reality feature.

## Checking the visuals

`UIRefreshScreenshotTests.testCaptureReviewScreens` walks the screens above
and writes PNGs to `/tmp/wbhb-screens`. It was written without a build, so
expect to adjust a selector or two on first run. Run it on an erased
simulator:

```bash
xcodebuild test -project wevebeenherebefore.xcodeproj -scheme wevebeenherebefore \
  -destination 'platform=iOS Simulator,name=<installed device>' \
  -parallel-testing-enabled NO \
  -only-testing:wevebeenherebeforeUITests/UIRefreshScreenshotTests/testCaptureReviewScreens
```

| Screenshot | What to look at |
| --- | --- |
| `r01`, `r02` resilience | Check-in card colours against cards; a long memory at 32pt |
| `r03` check-in editor | Original prediction box above the keyboard |
| `r04` verdict | Prediction / reality card |
| `r05`–`r07` detail, 2 weeks | Section order, gray answers, blue buttons, check-in boxes |
| `r08`–`r10` detail, 3 months | Add Summary button, summary editor, summary block |
| `r11`, `r12` prompts | No progress indicator or back control |
| `r13`, `r14` review step | "Back" closes the sheet; don't tap it in the test |
| `r15`, `r16` Remember | Top gap from nested stacks; both card types |
| `r17`, `r18` toolkit carousel | Top gap; card sizing |
| `r19` episodes list | Row content, year dividers, floating button overlap |
| `r20` filter menu | Mixed filter / sort / shuffle items |

Most of these views also have a `#Preview` with seeded data, which is quicker
for iterating on a single screen. The nested-stack gap and the review-step
"Back" behaviour only show inside the real flow.

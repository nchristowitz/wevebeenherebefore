import XCTest

// Walks the app's screens and saves screenshots to /tmp/wbhb-screens for
// review. Run each test on its own against an erased simulator with
// -parallel-testing-enabled NO so Debug Tools seeding is deterministic:
//
//   -only-testing:wevebeenherebeforeUITests/UIRefreshScreenshotTests/testCaptureRefreshedScreens
//   -only-testing:wevebeenherebeforeUITests/UIRefreshScreenshotTests/testCaptureReviewScreens
final class UIRefreshScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureRefreshedScreens() throws {
        let app = XCUIApplication()
        app.launch()

        seedViaDebugTools(app)

        // ---- Resilience tab: redesigned check-in cards ----
        app.tabBars.buttons["Resilience"].tap()
        let checkInCard = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS 'Check-in'")).firstMatch
        XCTAssertTrue(checkInCard.waitForExistence(timeout: 5))
        saveShot(app, name: "1-resilience-checkin-cards")

        // Song cards (text+song row, image+text+song pill) sit below the fold
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.8)
        saveShot(app, name: "1a-resilience-song-cards")

        // ---- Card editors: floating glass accessory chips ----
        app.buttons["Add Card"].tap()
        app.buttons["Add Delight"].tap()
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add Song"].exists, "Delight editor should offer Add Song")
        Thread.sleep(forTimeInterval: 1) // keyboard settles
        saveShot(app, name: "1b-add-delight-accessories")
        app.buttons["Back"].tap()

        app.buttons["Add Card"].tap()
        app.buttons["Add Memory"].tap()
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add Song"].exists, "Memory editor should offer Add Song")
        Thread.sleep(forTimeInterval: 1)
        saveShot(app, name: "1c-add-memory-accessories")

        // The styled date capsule must still open the calendar popover
        // through the invisible compact picker overlaid on it
        app.datePickers.firstMatch.tap()
        Thread.sleep(forTimeInterval: 1.5)
        saveShot(app, name: "1d-add-memory-datepicker-open")
        let dismissRegion = app.otherElements["PopoverDismissRegion"]
        let popoverOpened = dismissRegion.exists
            || app.buttons["Next Month"].exists
            || app.datePickers.count > 1
        XCTAssertTrue(popoverOpened,
                      "Calendar popover should open from the styled date capsule")
        if dismissRegion.exists {
            dismissRegion.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
        }
        app.buttons["Back"].tap()

        // ---- Episodes tab: year dividers ----
        app.tabBars.buttons["Episodes"].tap()
        let olderYearDivider = app.staticTexts["2025"]
        _ = olderYearDivider.waitForExistence(timeout: 3)
        var swipes = 0
        while !olderYearDivider.exists && swipes < 5 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(olderYearDivider.exists,
                      "Year divider for the older year should be reachable")
        saveShot(app, name: "2-episodes-year-dividers")
        if swipes > 0 { app.swipeDown() }

        // ---- Emotion rating: tap to set, tap again to clear ----
        app.buttons["Start Episode"].tap()
        XCTAssertTrue(app.staticTexts["What are you feeling right now?"].waitForExistence(timeout: 5))

        // First "4" in the hierarchy belongs to the first row (Anger)
        let angerFour = app.staticTexts.matching(NSPredicate(format: "label == '4'")).firstMatch
        XCTAssertTrue(angerFour.waitForExistence(timeout: 5))
        angerFour.tap()
        Thread.sleep(forTimeInterval: 0.6)
        saveShot(app, name: "3-rating-anger-4-set")

        angerFour.tap()
        Thread.sleep(forTimeInterval: 0.6)
        saveShot(app, name: "4-rating-anger-cleared")

        app.buttons["Next"].tap()

        // ---- Prompt screen: glass Next button above the keyboard ----
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Trying out the refreshed next button")
        Thread.sleep(forTimeInterval: 0.6)
        saveShot(app, name: "5-prompt-keyboard-next")

        // The button actually advances to the next prompt
        app.buttons["Next"].tap()
        XCTAssertTrue(app.staticTexts["How do you think you'll feel tomorrow?"]
            .waitForExistence(timeout: 5))

        // Leave without saving so the store stays as seeded
        app.terminate()
    }

    // Screens flagged in REVIEW-2026.md that the test above doesn't reach:
    // check-in editor and verdict, episode detail, summary editor, the
    // review step, and the Remember / toolkit carousels. Saves a check-in,
    // a summary, a memory card and one new episode into the store.
    @MainActor
    func testCaptureReviewScreens() throws {
        let app = XCUIApplication()
        app.launch()

        seedViaDebugTools(app)

        // ---- A long text-only memory, to see 32pt type on a tall card ----
        app.tabBars.buttons["Resilience"].tap()
        app.buttons["Add Card"].tap()
        app.buttons["Add Memory"].tap()
        enter("Looking back, the presentation went far better than I feared. "
             + "Nobody remembered the slip I spent a week replaying, and I "
             + "learned that the dread beforehand is nearly always worse than "
             + "the thing itself.", into: app)
        app.navigationBars.buttons["Save"].tap()
        Thread.sleep(forTimeInterval: 0.8)
        saveShot(app, name: "r01-resilience-top")
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.8)
        saveShot(app, name: "r02-resilience-long-memory")
        app.swipeDown()

        // ---- Check-in editor, then the prediction-vs-reality verdict ----
        let twoWeekCard = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH '2 Week Check-in'")).firstMatch
        XCTAssertTrue(twoWeekCard.waitForExistence(timeout: 5))
        twoWeekCard.tap()
        enter("Honestly I had to think to remember what I was so worried "
             + "about. Nobody has mentioned it since.", into: app)
        saveShot(app, name: "r03-checkin-editor")
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["We've been here before"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        saveShot(app, name: "r04-checkin-verdict")
        app.buttons["Continue"].tap()

        // ---- Episode detail with a completed check-in ----
        app.tabBars.buttons["Episodes"].tap()
        openEpisode(daysAgo: 14, in: app)
        saveShot(app, name: "r05-detail-2w-top")
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.6)
        saveShot(app, name: "r06-detail-2w-middle")
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.6)
        saveShot(app, name: "r07-detail-2w-bottom")
        app.navigationBars.buttons.firstMatch.tap()

        // ---- Episode detail at 3 months: summary available ----
        openEpisode(daysAgo: 90, in: app)
        let addSummary = app.buttons["Add Summary"]
        XCTAssertTrue(addSummary.waitForExistence(timeout: 5))
        saveShot(app, name: "r08-detail-3m-add-summary")
        addSummary.tap()
        enter("It passed, like the others did. What helped most was telling "
             + "someone early instead of carrying it alone.", into: app)
        saveShot(app, name: "r09-summary-editor")
        app.navigationBars.buttons["Save"].tap()
        Thread.sleep(forTimeInterval: 1)
        saveShot(app, name: "r10-detail-3m-with-summary")
        app.navigationBars.buttons.firstMatch.tap()

        // ---- Full episode flow through to the carousels ----
        app.buttons["Start Episode"].tap()
        XCTAssertTrue(app.staticTexts["What are you feeling right now?"].waitForExistence(timeout: 5))
        // Rows are alphabetical: first "4" is Anger, second "5" is Anxiety
        app.staticTexts.matching(NSPredicate(format: "label == '4'")).firstMatch.tap()
        app.staticTexts.matching(NSPredicate(format: "label == '5'")).element(boundBy: 1).tap()
        app.buttons["Next"].tap()

        let prompts: [(question: String, answer: String, button: String)] = [
            ("Describe the episode",
             "An email from my manager asking to talk tomorrow, no context. I have assumed the worst all evening.",
             "Next"),
            ("How do you think you'll feel tomorrow?",
             "Sick with nerves until the call, then either relieved or flattened.",
             "Next"),
            ("How do you think you'll feel about this in 2 weeks?",
             "Still turning it over, wondering what I should have said.",
             "Next"),
            ("What's the worst that can happen?",
             "They tell me the project is cancelled and my role with it.",
             "Next"),
            ("What would Christina say?",
             "That one vague email is not evidence of anything yet.",
             "Next"),
            ("How will you feel 3 months from now?",
             "I probably won't remember which email this was.",
             "Next"),
            ("Let's give this episode a title",
             "The vague email",
             "Done"),
        ]

        for (index, prompt) in prompts.enumerated() {
            XCTAssertTrue(app.staticTexts[prompt.question].waitForExistence(timeout: 5),
                          "Missing prompt: \(prompt.question)")
            enter(prompt.answer, into: app)
            if index == 0 { saveShot(app, name: "r11-flow-first-prompt") }
            if index == prompts.count - 1 { saveShot(app, name: "r12-flow-title-prompt") }
            app.buttons[prompt.button].tap()
        }

        // Review step. "Back" here closes the whole sheet — don't tap it.
        let saveEpisode = app.navigationBars.buttons["Save"]
        XCTAssertTrue(saveEpisode.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        saveShot(app, name: "r13-flow-review-top")
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.6)
        saveShot(app, name: "r14-flow-review-scrolled")
        saveEpisode.tap()

        // Saving requests notification permission on a fresh simulator
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 3) { allow.tap() }

        // Remember carousel: one summary card and one prediction/reality
        // card exist from the steps above, in shuffled order
        XCTAssertTrue(app.staticTexts["We've Been Here Before, Remember?"].waitForExistence(timeout: 8))
        Thread.sleep(forTimeInterval: 1)
        saveShot(app, name: "r15-remember-card-1")
        app.swipeLeft()
        Thread.sleep(forTimeInterval: 0.8)
        saveShot(app, name: "r16-remember-card-2")
        app.buttons["Continue"].tap()

        // Toolkit carousel
        XCTAssertTrue(app.staticTexts["From your resilience toolkit"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.8)
        saveShot(app, name: "r17-reminders-card-1")
        app.swipeLeft()
        Thread.sleep(forTimeInterval: 0.8)
        saveShot(app, name: "r18-reminders-card-2")
        app.buttons["Continue"].tap()

        // ---- Episodes list with the new episode, then the filter menu ----
        Thread.sleep(forTimeInterval: 1)
        saveShot(app, name: "r19-episodes-list")

        app.tabBars.buttons["Resilience"].tap()
        let filter = app.buttons["Filter"]
        if filter.waitForExistence(timeout: 3) {
            filter.tap()
            Thread.sleep(forTimeInterval: 0.8)
            saveShot(app, name: "r20-resilience-filter-menu")
        }

        app.terminate()
    }

    // Focuses the first text editor on screen and types into it
    private func enter(_ text: String, into app: XCUIApplication) {
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6) // keyboard and delayed focus settle
        editor.tap()
        editor.typeText(text)
        Thread.sleep(forTimeInterval: 0.4)
    }

    // Opens the episode logged the given number of days ago. Debug Tools
    // picks titles at random, so rows are found by their date label, which
    // uses the same format as EpisodesListView.
    private func openEpisode(daysAgo: Int, in app: XCUIApplication) {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        let label = date.formatted(.dateTime.month().day())
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label ENDSWITH %@", label)).firstMatch

        var swipes = 0
        while !row.waitForExistence(timeout: 2) && swipes < 3 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(row.exists, "No episode row dated \(label)")
        row.tap()
        XCTAssertTrue(app.staticTexts["Emotions"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 0.6)
    }

    // Seeds episodes at each check-in horizon plus two song delights
    private func seedViaDebugTools(_ app: XCUIApplication) {
        app.tabBars.buttons["Settings"].tap()

        let debugButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Debug Tools'")).firstMatch
        XCTAssertTrue(debugButton.waitForExistence(timeout: 5))
        if !debugButton.isHittable { app.swipeUp() }
        debugButton.tap()

        for seed in [
            "Add Recent Episode (24h ago)",
            "Add Episode (2 weeks ago)",
            "Add Episode (3 months ago)",
            "Add Episode (18 months ago)",
            "Add Delight with Song",
        ] {
            let seedButton = app.buttons[seed]
            XCTAssertTrue(seedButton.waitForExistence(timeout: 5), "Missing debug button: \(seed)")
            seedButton.tap()
            let ok = app.alerts.firstMatch.buttons["OK"]
            XCTAssertTrue(ok.waitForExistence(timeout: 5))
            ok.tap()
        }
        app.buttons["Done"].tap()
    }

    private func saveShot(_ app: XCUIApplication, name: String) {
        let shot = app.screenshot()
        let dir = URL(fileURLWithPath: "/tmp/wbhb-screens", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: dir.appendingPathComponent("\(name).png"))

        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

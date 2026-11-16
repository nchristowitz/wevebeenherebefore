import XCTest

// Walks the screens touched by the UI refresh (check-in cards, year
// dividers, rating toggle, prompt action button) and saves screenshots
// to /tmp/wbhb-screens for review. Run against an erased simulator with
// -parallel-testing-enabled NO so Debug Tools seeding is deterministic.
final class UIRefreshScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureRefreshedScreens() throws {
        let app = XCUIApplication()
        app.launch()

        // ---- Seed episodes via Debug Tools ----
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

        // ---- Episodes tab: check-in cards above the episode history ----
        app.tabBars.buttons["Episodes"].tap()
        let checkInCard = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS 'Check-in'")).firstMatch
        XCTAssertTrue(checkInCard.waitForExistence(timeout: 5))
        saveShot(app, name: "1-episodes-checkin-cards")

        // ---- Resilience tab: song cards (text+song row, image+text+song pill) ----
        app.tabBars.buttons["Resilience"].tap()
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

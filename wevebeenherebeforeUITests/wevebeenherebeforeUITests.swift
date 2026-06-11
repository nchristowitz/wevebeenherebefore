//
//  wevebeenherebeforeUITests.swift
//  wevebeenherebeforeUITests
//
//  Created by Nicholas Christowitz on 03.02.25.
//

import XCTest

final class wevebeenherebeforeUITests: XCTestCase {

    override func setUpWithError() throws {
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
    }

    // Completes a pending check-in and verifies the prediction-vs-reality
    // verdict moment appears. Requires an episode with an active check-in
    // window and a prediction on record (the local store must be seeded —
    // see the episode flow, or a planted fixture store).
    @MainActor
    func testCheckInShowsVerdictMoment() throws {
        let app = XCUIApplication()
        app.launch()

        // A pending check-in card on the Resilience tab (the default tab)
        let checkInCard = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH '24 Hour Check-in'"))
            .firstMatch
        guard checkInCard.waitForExistence(timeout: 5) else {
            throw XCTSkip("No pending 24h check-in available — store not seeded")
        }
        checkInCard.tap()

        // Write the check-in
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Honestly, nobody cared. One colleague even thanked me because the wrong file was useful to her. I was fine by lunchtime.")

        app.buttons["Save"].tap()

        // The verdict moment: prediction next to what was just written.
        // Match section labels case-insensitively — .textCase changes how
        // SwiftUI exposes them to accessibility.
        XCTAssertTrue(app.staticTexts["We've been here before"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] 'you predicted'")).firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] 'day later'")).firstMatch.exists)

        // Hold the verdict on screen briefly so external tooling can capture it
        Thread.sleep(forTimeInterval: 10)

        app.buttons["Continue"].tap()

        // Sheet closes; back on the Resilience tab and the card is gone
        XCTAssertTrue(app.staticTexts["We've been here before"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(checkInCard.exists)
    }
}

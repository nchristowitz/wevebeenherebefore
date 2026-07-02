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

        // The card label reads "24 Hour Check-in for episode {title}, {time
        // remaining}" — remember the title so the episode can be deleted later
        let cardLabel = checkInCard.label
        guard let titleStart = cardLabel.range(of: "for episode ")?.upperBound,
              let titleEnd = cardLabel.range(of: ",", options: .backwards)?.lowerBound,
              titleStart < titleEnd else {
            XCTFail("Unexpected check-in card label: \(cardLabel)")
            return
        }
        let episodeTitle = String(cardLabel[titleStart..<titleEnd])

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

        // Regression: deleting an episode right after completing its check-in
        // used to hit a SwiftData fault on the detached model and freeze.
        // Seeded stores can hold same-titled episodes, so assert on the count.
        app.tabBars.buttons["Episodes"].tap()
        let matchingRows = app.staticTexts.matching(
            NSPredicate(format: "label == %@", episodeTitle))
        let episodeRow = matchingRows.firstMatch
        XCTAssertTrue(episodeRow.waitForExistence(timeout: 5))
        let rowsBefore = matchingRows.count
        episodeRow.swipeLeft()
        app.buttons["Delete"].tap()
        Thread.sleep(forTimeInterval: 1)
        XCTAssertEqual(matchingRows.count, rowsBefore - 1)

        // The app is still alive and responsive
        app.tabBars.buttons["Resilience"].tap()
        XCTAssertTrue(app.tabBars.buttons["Resilience"].isSelected)
    }
}

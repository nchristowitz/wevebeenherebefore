//
//  wevebeenherebeforeTests.swift
//  wevebeenherebeforeTests
//
//  Created by Nicholas Christowitz on 03.02.25.
//

import Testing
import SwiftData
import SwiftUI
@testable import wevebeenherebefore

struct ExportImportRoundTripTests {

    // Exporting to JSON and importing into a fresh store must preserve
    // everything — especially summaries and card photos, which the app's
    // backup story depends on.
    @Test func jsonRoundTripPreservesAllData() async throws {
        // Build a source store with one fully-populated episode and card
        let sourceContainer = try ModelContainer(
            for: Episode.self, Card.self, EpisodeNote.self, CheckIn.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let sourceContext = ModelContext(sourceContainer)

        let episode = Episode(
            title: "Roundtrip Episode",
            emotions: ["Anxiety": 4, "Sadness": 2],
            prompts: ["Describe the episode": "It was a \"hard\" day,\nwith a comma"]
        )
        episode.summary = "Looking back, it passed like everything does."
        episode.summaryCreatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        episode.dismissedCheckIns = [CheckInType.twentyFourHour.rawValue]
        sourceContext.insert(episode)

        let note = EpisodeNote(text: "A note from later", episode: episode)
        sourceContext.insert(note)

        let checkIn = CheckIn(text: "Two weeks on, calmer", checkInType: .twoWeek, episode: episode)
        sourceContext.insert(checkIn)

        let imageBytes = Data([0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x01, 0x02, 0x03])
        let card = Card(
            text: "The cat's fur",
            type: .delight,
            color: Color(.sRGB, red: 0.8, green: 0.4, blue: 0.2, opacity: 1),
            imageData: imageBytes
        )
        sourceContext.insert(card)
        try sourceContext.save()

        // Export
        let url = try #require(ExportManager.shared.exportData(
            episodes: [episode], cards: [card], format: .json
        ))

        // Import into a fresh store
        let destContainer = try ModelContainer(
            for: Episode.self, Card.self, EpisodeNote.self, CheckIn.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let destContext = ModelContext(destContainer)
        let result = try await ImportManager.shared.importData(from: url, into: destContext)

        #expect(result.episodes == 1)
        #expect(result.cards == 1)
        #expect(result.notes == 1)
        #expect(result.checkIns == 1)

        // Verify the episode survived intact
        let importedEpisodes = try destContext.fetch(FetchDescriptor<Episode>())
        let importedEpisode = try #require(importedEpisodes.first)
        #expect(importedEpisode.title == "Roundtrip Episode")
        #expect(importedEpisode.emotions == ["Anxiety": 4, "Sadness": 2])
        #expect(importedEpisode.prompts["Describe the episode"] == "It was a \"hard\" day,\nwith a comma")
        #expect(importedEpisode.summary == "Looking back, it passed like everything does.")
        #expect(importedEpisode.summaryCreatedAt == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(importedEpisode.dismissedCheckIns == [CheckInType.twentyFourHour.rawValue])
        #expect(importedEpisode.notes.count == 1)
        #expect(importedEpisode.notes.first?.text == "A note from later")
        #expect(importedEpisode.checkIns.count == 1)
        #expect(importedEpisode.checkIns.first?.checkInType == .twoWeek)

        // Verify the card photo survived intact
        let importedCards = try destContext.fetch(FetchDescriptor<Card>())
        let importedCard = try #require(importedCards.first)
        #expect(importedCard.text == "The cat's fur")
        #expect(importedCard.type == .delight)
        #expect(importedCard.imageData == imageBytes)
    }

    // Quotes in user text must not corrupt CSV columns
    @Test func csvExportEscapesQuotes() throws {
        let card = Card(text: "She said \"breathe\"", type: .technique, color: .blue)

        let url = try #require(ExportManager.shared.exportData(
            episodes: [], cards: [card], format: .csv
        ))
        let csv = try String(contentsOf: url, encoding: .utf8)

        #expect(csv.contains("\"She said \"\"breathe\"\"\""))
    }
}

struct CheckInWindowTests {

    // The 24h window is the calendar day after the episode; the countdown
    // and the active check shown in the UI both derive from checkInWindow.
    @Test func twentyFourHourWindowIsNextCalendarDay() throws {
        let episode = Episode(title: "Test", emotions: [:], prompts: [:])
        episode.date = Date()

        let window = try #require(episode.checkInWindow(for: .twentyFourHour))
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: episode.date)!

        #expect(window.start == calendar.startOfDay(for: tomorrow))
        #expect(window.end == calendar.dateInterval(of: .day, for: tomorrow)!.end)
        #expect(!episode.isCheckInWindowActive(for: .twentyFourHour))
    }

    @Test func pendingExcludesDismissedCheckIns() throws {
        let episode = Episode(title: "Test", emotions: [:], prompts: [:])
        // Put the episode 14 days in the past so the 2-week window is active
        episode.date = Calendar.current.date(byAdding: .day, value: -14, to: Date())!

        #expect(episode.isCheckInWindowActive(for: .twoWeek))
        #expect(episode.pendingCheckInTypes == [.twoWeek])
        #expect(episode.hasPendingCheckIn)

        episode.dismissCheckIn(for: .twoWeek)

        #expect(episode.pendingCheckInTypes.isEmpty)
        #expect(!episode.hasPendingCheckIn)
    }
}

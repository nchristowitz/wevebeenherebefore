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
        #expect(importedEpisode.uuid == episode.uuid)
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
        // pendingCheckInTypes requires a live context — detached models
        // (e.g. mid-deletion) deliberately report nothing pending
        let container = try ModelContainer(
            for: Episode.self, Card.self, EpisodeNote.self, CheckIn.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let episode = Episode(title: "Test", emotions: [:], prompts: [:])
        // Put the episode 14 days in the past so the 2-week window is active
        episode.date = Calendar.current.date(byAdding: .day, value: -14, to: Date())!

        // Unmanaged: no pending check-ins regardless of window state
        #expect(episode.pendingCheckInTypes.isEmpty)

        context.insert(episode)

        #expect(episode.isCheckInWindowActive(for: .twoWeek))
        #expect(episode.pendingCheckInTypes == [.twoWeek])
        #expect(episode.hasPendingCheckIn)

        episode.dismissCheckIn(for: .twoWeek)

        #expect(episode.pendingCheckInTypes.isEmpty)
        #expect(!episode.hasPendingCheckIn)
    }
}

struct EpisodeUUIDTests {

    // SwiftData's lightweight migration can stamp all pre-existing episodes
    // with the same default UUID; the launch backfill must make them unique
    // without touching episodes that already have distinct UUIDs.
    @Test func backfillRegeneratesDuplicateUUIDs() throws {
        let container = try ModelContainer(
            for: Episode.self, Card.self, EpisodeNote.self, CheckIn.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        // Simulate the post-migration state: three episodes sharing one UUID,
        // plus one that's already unique
        let sharedUUID = UUID()
        let uniqueUUID = UUID()
        for index in 0..<3 {
            let episode = Episode(title: "Duplicate \(index)", emotions: [:], prompts: [:])
            episode.uuid = sharedUUID
            context.insert(episode)
        }
        let distinctEpisode = Episode(title: "Distinct", emotions: [:], prompts: [:])
        distinctEpisode.uuid = uniqueUUID
        context.insert(distinctEpisode)
        try context.save()

        ensureUniqueEpisodeUUIDs(in: container)

        // Verify through a fresh context so we read persisted state, not
        // objects cached by the inserting context
        let verifyContext = ModelContext(container)
        let episodes = try verifyContext.fetch(FetchDescriptor<Episode>())
        let uuids = episodes.map(\.uuid)
        #expect(Set(uuids).count == 4)
        // The already-unique episode keeps its UUID
        #expect(episodes.first { $0.title == "Distinct" }?.uuid == uniqueUUID)
        // One of the duplicates keeps the original; the others were regenerated
        #expect(uuids.filter { $0 == sharedUUID }.count == 1)
    }

    @Test func newEpisodesGetDistinctUUIDs() {
        let a = Episode(title: "A", emotions: [:], prompts: [:])
        let b = Episode(title: "B", emotions: [:], prompts: [:])
        #expect(a.uuid != b.uuid)
    }
}

struct PredictionRealityTests {

    @Test func predictionFindsCurrentAndLegacyPromptWordings() {
        let current = Episode(title: "Current", emotions: [:], prompts: [
            "How do you think you'll feel about this in 2 weeks?": "Still terrible",
            "How will you feel 3 months from now?": "Probably fine"
        ])
        #expect(current.prediction(for: .twoWeek) == "Still terrible")
        #expect(current.prediction(for: .threeMonth) == "Probably fine")
        #expect(current.prediction(for: .twentyFourHour) == nil)

        // Old episodes carry wordings from earlier versions of the flow
        let legacy = Episode(title: "Legacy", emotions: [:], prompts: [
            "How do you think you'll feel two weeks from now?": "Awful, surely",
            "What about 3 months from now?": "Who knows"
        ])
        #expect(legacy.prediction(for: .twoWeek) == "Awful, surely")
        #expect(legacy.prediction(for: .threeMonth) == "Who knows")
    }

    @Test func pairsRequireBothPredictionAndCheckIn() {
        let episode = Episode(title: "Test", emotions: [:], prompts: [
            "How do you think you'll feel tomorrow?": "Dreadful",
            "How do you think you'll feel about this in 2 weeks?": "Embarrassed forever"
        ])

        // No check-ins yet — no pairs despite two predictions
        #expect(episode.predictionRealityPairs.isEmpty)
        #expect(episode.bestPredictionRealityPair == nil)

        // A 2w check-in completes that pair only
        let twoWeek = CheckIn(text: "Barely think about it", checkInType: .twoWeek, episode: episode)
        episode.checkIns.append(twoWeek)

        let pairs = episode.predictionRealityPairs
        #expect(pairs.count == 1)
        #expect(pairs.first?.checkInType == .twoWeek)
        #expect(pairs.first?.prediction == "Embarrassed forever")
        #expect(pairs.first?.reality == "Barely think about it")

        // A 3m check-in without a matching prediction prompt adds no pair
        let threeMonth = CheckIn(text: "What episode?", checkInType: .threeMonth, episode: episode)
        episode.checkIns.append(threeMonth)
        #expect(episode.predictionRealityPairs.count == 1)
    }

    @Test func bestPairPrefersLongestHorizon() {
        let episode = Episode(title: "Test", emotions: [:], prompts: [
            "How do you think you'll feel tomorrow?": "Dreadful",
            "How will you feel 3 months from now?": "Scarred for life"
        ])
        episode.checkIns.append(CheckIn(text: "Rough but ok", checkInType: .twentyFourHour, episode: episode))
        episode.checkIns.append(CheckIn(text: "Completely forgotten", checkInType: .threeMonth, episode: episode))

        #expect(episode.predictionRealityPairs.count == 2)
        #expect(episode.bestPredictionRealityPair?.checkInType == .threeMonth)
    }
}

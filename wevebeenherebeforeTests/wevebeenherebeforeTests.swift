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

// Serialized: export file names are only unique to the second, so
// parallel export tests could overwrite each other's file
@Suite(.serialized)
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
        let artworkBytes = Data([0xCA, 0xFE, 0xF0, 0x0D])
        let song = CardSong(
            persistentID: "12345678901234567890",
            storeID: "1440783625",
            title: "Here Comes the Sun",
            artist: "The Beatles",
            artworkData: artworkBytes
        )
        let card = Card(
            text: "The cat's fur",
            type: .delight,
            color: Color(.sRGB, red: 0.8, green: 0.4, blue: 0.2, opacity: 1),
            imageData: imageBytes,
            song: song
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

        // Verify the card photo and song survived intact
        let importedCards = try destContext.fetch(FetchDescriptor<Card>())
        let importedCard = try #require(importedCards.first)
        #expect(importedCard.text == "The cat's fur")
        #expect(importedCard.type == .delight)
        #expect(importedCard.imageData == imageBytes)
        #expect(importedCard.song == song)
    }

    // Importing the same backup twice must not duplicate anything
    @Test func importingTheSameBackupTwiceAddsNothingTheSecondTime() async throws {
        let container = try ModelContainer(
            for: Episode.self, Card.self, EpisodeNote.self, CheckIn.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let episode = Episode(title: "Once only", emotions: ["Fear": 3], prompts: ["Describe the episode": "Hm"])
        let card = Card(text: "Coffee walk", type: .technique, color: .green)
        let url = try #require(ExportManager.shared.exportData(episodes: [episode], cards: [card], format: .json))

        let first = try await ImportManager.shared.importData(from: url, into: context)
        #expect(first.episodes == 1)
        #expect(first.cards == 1)
        #expect(first.skippedDuplicates == 0)

        let second = try await ImportManager.shared.importData(from: url, into: context)
        #expect(second.episodes == 0)
        #expect(second.cards == 0)
        #expect(second.skippedDuplicates == 2)

        #expect(try context.fetch(FetchDescriptor<Episode>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Card>()).count == 1)
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

struct PromptOrderTests {

    // The episode detail shows answers in prompt order, linking each
    // prediction to its check-in — including under earlier wordings
    @Test func answeredPromptsFollowPromptOrderAcrossWordings() {
        let answered = EpisodePrompt.answeredPrompts(from: [
            "How do you think you'll feel about this in 3 months?": "Fine, probably",
            "What triggered it?": "An email",
            "Describe the episode": "A bad afternoon",
            "How do you think you'll feel tomorrow?": "Tired",
            EpisodePrompt.titleQuestion: "Bad afternoon"
        ])

        #expect(answered.map(\.question) == [
            "Describe the episode",
            "How do you think you'll feel tomorrow?",
            "How do you think you'll feel about this in 3 months?",
            "What triggered it?"
        ])
        #expect(answered.map(\.checkInType) == [nil, .twentyFourHour, .threeMonth, nil])
    }

    @Test func predictionFindsEveryThreeMonthWording() {
        let episode = Episode(title: "Old", emotions: [:], prompts: [
            "How do you think you'll feel about this in 3 months?": "Long forgotten"
        ])
        #expect(episode.prediction(for: .threeMonth) == "Long forgotten")
    }
}

struct CardStorageTests {

    // White and black are grayscale colors with only two components;
    // reading them as RGB used to risk an out-of-range crash
    @Test func grayscaleColorsStoreAsRGB() {
        let white = Card(text: "", type: .technique, color: .white)
        #expect(white.colorRed == 1 && white.colorGreen == 1 && white.colorBlue == 1)
        #expect(Color.white.contrastingTextColor() == .black)

        let black = Card(text: "", type: .technique, color: .black)
        #expect(black.colorRed == 0 && black.colorGreen == 0 && black.colorBlue == 0)
        #expect(Color.black.contrastingTextColor() == .white)
    }

    @Test func largePhotosAreDownscaledAndSmallOnesKept() throws {
        func jpeg(width: Int, height: Int) -> Data {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
                UIColor.orange.setFill()
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            }
            return image.jpegData(compressionQuality: 0.9)!
        }

        let large = try #require(Card.downscaledImageData(jpeg(width: 4000, height: 3000)))
        let resized = try #require(UIImage(data: large))
        #expect(max(resized.size.width, resized.size.height) == CGFloat(Card.maxImagePixelSize))

        #expect(Card.downscaledImageData(jpeg(width: 1200, height: 900)) == nil)
    }
}

struct DarkModeCardColorTests {

    private func contrastWithWhite(_ color: Color) -> Double {
        let rgb = color.sRGBComponents
        func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let luminance = 0.2126 * linear(rgb.red) + 0.7152 * linear(rgb.green) + 0.0722 * linear(rgb.blue)
        return 1.05 / (luminance + 0.05)
    }

    // Every card color, however bright, gets a dark version that carries
    // white text at Apple's recommended 7:1 contrast
    @Test func darkVariantsCarryWhiteTextAtSevenToOne() {
        let samples: [Color] = [
            Color(.sRGB, red: 1.00, green: 0.84, blue: 0.04),  // yellow
            Color(.sRGB, red: 1.00, green: 0.58, blue: 0.00),  // orange
            Color(.sRGB, red: 1.00, green: 0.71, blue: 0.76),  // pastel pink
            Color(.sRGB, red: 0.40, green: 0.80, blue: 0.40),  // green
            Color(.sRGB, red: 0.35, green: 0.78, blue: 0.98),  // sky blue
            Color(.sRGB, red: 0.35, green: 0.34, blue: 0.84),  // indigo
            Color(.sRGB, red: 0.91, green: 0.30, blue: 0.24),  // red
            .white,
            Card.defaultColor,
            .black
        ]

        for color in samples {
            let dark = color.darkCardVariant
            #expect(dark.contrastingTextColor() == .white)
            #expect(contrastWithWhite(dark) >= 7)
        }
    }

    @Test func lightModeShowsTheChosenColor() {
        let chosen = Color(.sRGB, red: 1.00, green: 0.84, blue: 0.04)
        #expect(chosen.cardColor(for: .light) == chosen)
    }
}

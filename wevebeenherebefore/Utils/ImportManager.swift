//
//  ImportManager.swift
//  wevebeenherebefore
//
//  Created by Nicholas Christowitz on [DATE].
//

import Foundation
import SwiftData
import SwiftUI

class ImportManager {
    static let shared = ImportManager()
    private init() {}
    
    // @MainActor: callers pass SwiftUI's main model context, which must only
    // be touched on the main actor — without this, the await hops the body
    // onto a background executor and SwiftData crashes
    @MainActor
    func importData(from url: URL, into modelContext: ModelContext) async throws -> ImportResult {
        // startAccessingSecurityScopedResource returns false for URLs that
        // aren't security-scoped (e.g. files already inside our sandbox) —
        // that's not an error, so proceed and let the read fail if blocked.
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        let data = try Data(contentsOf: url)
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "json":
            return try await importFromJSON(data: data, into: modelContext)
        case "csv":
            throw ImportError.unsupportedFormat
        case "md":
            throw ImportError.unsupportedFormat
        default:
            throw ImportError.unsupportedFormat
        }
    }
    
    @MainActor
    private func importFromJSON(data: Data, into modelContext: ModelContext) async throws -> ImportResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ImportError.invalidFormat
        }

        let iso8601 = ISO8601DateFormatter()
        func date(_ value: Any?) -> Date? {
            (value as? String).flatMap { iso8601.date(from: $0) }
        }

        // What's already stored, so importing the same backup twice (or a
        // backup into a phone that has some of it) adds nothing twice
        var existingEpisodes = try modelContext.fetch(FetchDescriptor<Episode>())
        var existingCards = try modelContext.fetch(FetchDescriptor<Card>())

        var importedEpisodes: [Episode] = []
        var importedCards = 0
        var importedNotes = 0
        var importedCheckIns = 0
        var skippedDuplicates = 0

        // Import Episodes
        if let episodesData = json["episodes"] as? [[String: Any]] {
            for episodeDict in episodesData {
                guard let title = episodeDict["title"] as? String,
                      let emotions = episodeDict["emotions"] as? [String: Int],
                      let prompts = episodeDict["prompts"] as? [String: String] else { continue }

                let uuid = (episodeDict["uuid"] as? String).flatMap { UUID(uuidString: $0) }
                let createdAt = date(episodeDict["createdAt"])

                // Same episode: same stable ID, or (for backups from before
                // IDs existed) same title created at the same moment
                let isDuplicate = existingEpisodes.contains { existing in
                    if let uuid, existing.uuid == uuid { return true }
                    guard let createdAt else { return false }
                    return existing.title == title && isSameMoment(existing.createdAt, createdAt)
                }
                if isDuplicate {
                    skippedDuplicates += 1
                    continue
                }

                let episode = Episode(title: title, emotions: emotions, prompts: prompts)

                // Keep the episode's stable identity if the export carried one
                if let uuid {
                    episode.uuid = uuid
                }

                // Set the original date if available
                if let date = date(episodeDict["date"]) {
                    episode.date = date
                }

                if let createdAt {
                    episode.createdAt = createdAt
                }

                if let summary = episodeDict["summary"] as? String {
                    episode.summary = summary
                }

                if let summaryCreated = date(episodeDict["summaryCreatedAt"]) {
                    episode.summaryCreatedAt = summaryCreated
                }

                if let dismissed = episodeDict["dismissedCheckIns"] as? [String] {
                    episode.dismissedCheckIns = dismissed
                }

                modelContext.insert(episode)
                importedEpisodes.append(episode)
                existingEpisodes.append(episode)

                // Import Notes for this episode
                if let notesData = episodeDict["notes"] as? [[String: Any]] {
                    for noteDict in notesData {
                        guard let text = noteDict["text"] as? String else { continue }

                        let note = EpisodeNote(text: text, episode: episode)

                        if let created = date(noteDict["createdAt"]) {
                            note.createdAt = created
                        }

                        modelContext.insert(note)
                        importedNotes += 1
                    }
                }

                // Import Check-ins for this episode
                if let checkInsData = episodeDict["checkIns"] as? [[String: Any]] {
                    for checkInDict in checkInsData {
                        guard let text = checkInDict["text"] as? String,
                              let typeString = checkInDict["type"] as? String,
                              let checkInType = CheckInType(rawValue: typeString) else { continue }

                        let checkIn = CheckIn(text: text, checkInType: checkInType, episode: episode)

                        if let created = date(checkInDict["createdAt"]) {
                            checkIn.createdAt = created
                        }

                        modelContext.insert(checkIn)
                        importedCheckIns += 1
                    }
                }
            }
        }

        // Import Cards
        if let cardsData = json["cards"] as? [[String: Any]] {
            for cardDict in cardsData {
                guard let text = cardDict["text"] as? String,
                      let typeString = cardDict["type"] as? String,
                      let cardType = CardType(rawValue: typeString) else { continue }

                let createdAt = date(cardDict["createdAt"])

                // Cards have no stable ID: the same type and text created at
                // the same moment is the same card
                if let createdAt, existingCards.contains(where: {
                    $0.type == cardType && $0.text == text && isSameMoment($0.createdAt, createdAt)
                }) {
                    skippedDuplicates += 1
                    continue
                }

                // Extract color - using the same pattern as Card.swift
                var color = Color(.sRGB, red: 0.5, green: 0.5, blue: 0.5, opacity: 1) // Default gray
                if let colorDict = cardDict["color"] as? [String: Double],
                   let red = colorDict["red"],
                   let green = colorDict["green"],
                   let blue = colorDict["blue"] {
                    color = Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
                }

                // Extract date for memories
                let memoryDate = date(cardDict["date"])

                // Restore the photo if the export included one, at the same
                // screen size photos are stored at when picked
                var imageData: Data?
                if let base64 = cardDict["imageData"] as? String,
                   let original = Data(base64Encoded: base64) {
                    imageData = Card.downscaledImageData(original) ?? original
                }

                // Restore the song attachment if the export included one
                var song: CardSong?
                if let songDict = cardDict["song"] as? [String: Any],
                   let persistentID = songDict["persistentID"] as? String,
                   let title = songDict["title"] as? String {
                    var artworkData: Data?
                    if let artworkBase64 = songDict["artworkData"] as? String {
                        artworkData = Data(base64Encoded: artworkBase64)
                    }
                    song = CardSong(
                        persistentID: persistentID,
                        storeID: songDict["storeID"] as? String,
                        title: title,
                        artist: songDict["artist"] as? String ?? "",
                        artworkData: artworkData
                    )
                }

                let card = Card(text: text, type: cardType, color: color, date: memoryDate, imageData: imageData, song: song)

                if let createdAt {
                    card.createdAt = createdAt
                }

                modelContext.insert(card)
                existingCards.append(card)
                importedCards += 1
            }
        }

        try modelContext.save()

        // Imported episodes get reminders for any check-ins still ahead
        await NotificationManager.shared.checkPermission()
        if NotificationManager.shared.hasPermission, !importedEpisodes.isEmpty {
            for episode in importedEpisodes {
                episode.notificationIDs = NotificationManager.shared.scheduleRemainingNotifications(for: episode)
            }
            try modelContext.save()
        }

        return ImportResult(
            episodes: importedEpisodes.count,
            cards: importedCards,
            notes: importedNotes,
            checkIns: importedCheckIns,
            skippedDuplicates: skippedDuplicates
        )
    }

    // Exports store dates to the second; stored dates keep fractions
    private func isSameMoment(_ a: Date, _ b: Date) -> Bool {
        abs(a.timeIntervalSince(b)) < 1
    }
}

enum ImportError: LocalizedError {
    case fileAccessDenied
    case unsupportedFormat
    case invalidFormat
    case importFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .fileAccessDenied:
            return "Unable to access the selected file"
        case .unsupportedFormat:
            return "Unsupported file format. Please use JSON files exported from this app."
        case .invalidFormat:
            return "The file format is invalid or corrupted"
        case .importFailed(let message):
            return "Import failed: \(message)"
        }
    }
}

struct ImportResult {
    let episodes: Int
    let cards: Int
    let notes: Int
    let checkIns: Int
    // Episodes and cards already in the app, left untouched
    let skippedDuplicates: Int

    var totalItems: Int {
        episodes + cards + notes + checkIns
    }
}

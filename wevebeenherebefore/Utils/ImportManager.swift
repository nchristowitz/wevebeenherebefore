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
    
    func importData(from url: URL, into modelContext: ModelContext) async throws -> ImportResult {
        guard url.startAccessingSecurityScopedResource() else {
            throw ImportError.fileAccessDenied
        }
        
        defer { url.stopAccessingSecurityScopedResource() }
        
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
    
    private func importFromJSON(data: Data, into modelContext: ModelContext) async throws -> ImportResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ImportError.invalidFormat
        }
        
        var importedEpisodes = 0
        var importedCards = 0
        var importedNotes = 0
        var importedCheckIns = 0
        
        // Import Episodes
        if let episodesData = json["episodes"] as? [[String: Any]] {
            for episodeDict in episodesData {
                guard let title = episodeDict["title"] as? String,
                      let emotions = episodeDict["emotions"] as? [String: Int],
                      let prompts = episodeDict["prompts"] as? [String: String] else { continue }
                
                let episode = Episode(title: title, emotions: emotions, prompts: prompts)
                
                // Set the original date if available
                if let dateString = episodeDict["date"] as? String,
                   let date = ISO8601DateFormatter().date(from: dateString) {
                    episode.date = date
                }
                
                if let createdString = episodeDict["createdAt"] as? String,
                   let created = ISO8601DateFormatter().date(from: createdString) {
                    episode.createdAt = created
                }
                
                modelContext.insert(episode)
                importedEpisodes += 1
                
                // Import Notes for this episode
                if let notesData = episodeDict["notes"] as? [[String: Any]] {
                    for noteDict in notesData {
                        guard let text = noteDict["text"] as? String else { continue }
                        
                        let note = EpisodeNote(text: text, episode: episode)
                        
                        if let createdString = noteDict["createdAt"] as? String,
                           let created = ISO8601DateFormatter().date(from: createdString) {
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
                        
                        if let createdString = checkInDict["createdAt"] as? String,
                           let created = ISO8601DateFormatter().date(from: createdString) {
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
                
                // Extract color - using the same pattern as your Card.swift
                var color = Color(.sRGB, red: 0.5, green: 0.5, blue: 0.5, opacity: 1) // Default gray
                if let colorDict = cardDict["color"] as? [String: Double],
                   let red = colorDict["red"],
                   let green = colorDict["green"],
                   let blue = colorDict["blue"] {
                    color = Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
                }
                
                // Extract date for memories
                var date: Date?
                if let dateString = cardDict["date"] as? String {
                    date = ISO8601DateFormatter().date(from: dateString)
                }
                
                let card = Card(text: text, type: cardType, color: color, date: date, imageData: nil)
                
                if let createdString = cardDict["createdAt"] as? String,
                   let created = ISO8601DateFormatter().date(from: createdString) {
                    card.createdAt = created
                }
                
                modelContext.insert(card)
                importedCards += 1
            }
        }
        
        try modelContext.save()
        
        return ImportResult(
            episodes: importedEpisodes,
            cards: importedCards,
            notes: importedNotes,
            checkIns: importedCheckIns
        )
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
    
    var totalItems: Int {
        episodes + cards + notes + checkIns
    }
}

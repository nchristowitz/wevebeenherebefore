//
//  ExportManager.swift
//  wevebeenherebefore
//
//  Created by Nicholas Christowitz on 27.05.25.
//

import Foundation
import SwiftData

enum ExportFormat: String, CaseIterable {
    case csv = "CSV"
    case json = "JSON"
    case markdown = "Markdown"
    
    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .json: return "json"
        case .markdown: return "md"
        }
    }
}

class ExportManager {
    static let shared = ExportManager()
    private init() {}
    
    func exportData(episodes: [Episode], cards: [Card], format: ExportFormat) -> URL? {
        let fileName = "wbhb_export_\(dateFormatter.string(from: Date())).\(format.fileExtension)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            let content: String
            switch format {
            case .csv:
                content = generateCSV(episodes: episodes, cards: cards)
            case .json:
                content = generateJSON(episodes: episodes, cards: cards)
            case .markdown:
                content = generateMarkdown(episodes: episodes, cards: cards)
            }
            
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("Export error: \(error)")
            return nil
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
    
    private let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    // MARK: - CSV Export
    private func generateCSV(episodes: [Episode], cards: [Card]) -> String {
        var csv = ""
        
        // Episodes CSV
        csv += "EPISODES\n"
        csv += "Title,Date,Created,Emotions,Prompts\n"
        
        for episode in episodes.sorted(by: { $0.createdAt > $1.createdAt }) {
            let emotionsStr = episode.emotions.map { "\($0.key):\($0.value)" }.joined(separator: "; ")
            let promptsStr = episode.prompts.map { "\($0.key): \($0.value)" }.joined(separator: "; ")
            
            csv += "\"\(episode.title)\",\"\(displayDateFormatter.string(from: episode.date))\",\"\(displayDateFormatter.string(from: episode.createdAt))\",\"\(emotionsStr)\",\"\(promptsStr)\"\n"
        }
        
        csv += "\n"
        
        // Cards CSV
        csv += "CARDS\n"
        csv += "Type,Text,Date,Created\n"
        
        for card in cards.sorted(by: { $0.createdAt > $1.createdAt }) {
            let dateStr = card.date.map { displayDateFormatter.string(from: $0) } ?? ""
            csv += "\"\(card.type.rawValue)\",\"\(card.text)\",\"\(dateStr)\",\"\(displayDateFormatter.string(from: card.createdAt))\"\n"
        }
        
        csv += "\n"
        
        // Notes and Check-ins CSV
        csv += "NOTES_AND_CHECKINS\n"
        csv += "Episode Title,Type,Text,Created\n"
        
        for episode in episodes {
            // Notes
            for note in episode.notes.sorted(by: { $0.createdAt > $1.createdAt }) {
                csv += "\"\(episode.title)\",\"Note\",\"\(note.text)\",\"\(displayDateFormatter.string(from: note.createdAt))\"\n"
            }
            
            // Check-ins
            for checkIn in episode.checkIns.sorted(by: { $0.createdAt > $1.createdAt }) {
                csv += "\"\(episode.title)\",\"\(checkIn.checkInType.displayName)\",\"\(checkIn.text)\",\"\(displayDateFormatter.string(from: checkIn.createdAt))\"\n"
            }
        }
        
        return csv
    }
    
    // MARK: - JSON Export
    private func generateJSON(episodes: [Episode], cards: [Card]) -> String {
        let exportData: [String: Any] = [
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "appName": "We've Been Here Before",
            "version": "1.0",
            "episodes": episodes.map { episodeToDict($0) },
            "cards": cards.map { cardToDict($0) }
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? ""
        } catch {
            return "Error generating JSON: \(error)"
        }
    }
    
    private func episodeToDict(_ episode: Episode) -> [String: Any] {
        return [
            "title": episode.title,
            "date": ISO8601DateFormatter().string(from: episode.date),
            "createdAt": ISO8601DateFormatter().string(from: episode.createdAt),
            "emotions": episode.emotions,
            "prompts": episode.prompts,
            "notes": episode.notes.map { [
                "text": $0.text,
                "createdAt": ISO8601DateFormatter().string(from: $0.createdAt)
            ]},
            "checkIns": episode.checkIns.map { [
                "type": $0.checkInType.rawValue,
                "text": $0.text,
                "createdAt": ISO8601DateFormatter().string(from: $0.createdAt)
            ]}
        ]
    }
    
    private func cardToDict(_ card: Card) -> [String: Any] {
        var dict: [String: Any] = [
            "type": card.type.rawValue,
            "text": card.text,
            "createdAt": ISO8601DateFormatter().string(from: card.createdAt),
            "color": [
                "red": card.colorRed,
                "green": card.colorGreen,
                "blue": card.colorBlue
            ]
        ]
        
        if let date = card.date {
            dict["date"] = ISO8601DateFormatter().string(from: date)
        }
        
        if let imageData = card.imageData {
            dict["hasImage"] = true
            dict["imageSize"] = imageData.count
        }
        
        return dict
    }
    
    // MARK: - Markdown Export
    private func generateMarkdown(episodes: [Episode], cards: [Card]) -> String {
        var markdown = "# We've Been Here Before - Data Export\n\n"
        markdown += "Exported on: \(displayDateFormatter.string(from: Date()))\n\n"
        
        // Episodes
        markdown += "## Episodes\n\n"
        for episode in episodes.sorted(by: { $0.createdAt > $1.createdAt }) {
            markdown += "### \(episode.title)\n"
            markdown += "**Date:** \(displayDateFormatter.string(from: episode.date))\n\n"
            
            // Emotions
            if !episode.emotions.isEmpty {
                markdown += "**Emotions:**\n"
                for (emotion, rating) in episode.emotions.sorted(by: { $0.value > $1.value }) {
                    if rating > 0 {
                        markdown += "- \(emotion): \(rating)/5\n"
                    }
                }
                markdown += "\n"
            }
            
            // Prompts
            for (prompt, response) in episode.prompts {
                markdown += "**\(prompt):**\n\(response)\n\n"
            }
            
            // Notes
            if !episode.notes.isEmpty {
                markdown += "**Notes:**\n"
                for note in episode.notes.sorted(by: { $0.createdAt > $1.createdAt }) {
                    markdown += "- *\(displayDateFormatter.string(from: note.createdAt)):* \(note.text)\n"
                }
                markdown += "\n"
            }
            
            // Check-ins
            if !episode.checkIns.isEmpty {
                markdown += "**Check-ins:**\n"
                for checkIn in episode.checkIns.sorted(by: { $0.createdAt > $1.createdAt }) {
                    markdown += "- **\(checkIn.checkInType.displayName)** *(\(displayDateFormatter.string(from: checkIn.createdAt))):* \(checkIn.text)\n"
                }
                markdown += "\n"
            }
            
            markdown += "---\n\n"
        }
        
        // Cards
        markdown += "## Resilience Cards\n\n"
        
        let groupedCards = Dictionary(grouping: cards) { $0.type }
        
        for cardType in [CardType.memory, CardType.delight, CardType.technique] {
            if let cardsOfType = groupedCards[cardType], !cardsOfType.isEmpty {
                markdown += "### \(cardType.rawValue.capitalized)s\n\n"
                
                for card in cardsOfType.sorted(by: { $0.createdAt > $1.createdAt }) {
                    if let date = card.date {
                        markdown += "**\(displayDateFormatter.string(from: date)):** "
                    }
                    markdown += "\(card.text)\n\n"
                }
            }
        }
        
        return markdown
    }
}

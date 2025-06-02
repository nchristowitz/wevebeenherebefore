import SwiftUI
import SwiftData

struct EpisodeSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let emotions: [String: Int]
    private let prompts: [String: String]
    private let title: String
    private let episode: Episode?
    private let onSave: (() -> Void)?
    
    @State private var isShowingAddNote = false
    @State private var refreshID = UUID()
    @State private var editingNote: EpisodeNote?
    @State private var editingCheckIn: CheckIn?
    @State private var addingCheckInType: CheckInType?
    
    // For viewing existing episodes with notes
    init(episode: Episode) {
        self.emotions = episode.emotions
        self.prompts = episode.prompts
        self.title = episode.title
        self.episode = episode
        self.onSave = nil
    }
    
    // For standalone usage (like from episode flow)
    init(emotions: [String: Int], prompts: [String: String], title: String, onSave: @escaping () -> Void) {
        self.emotions = emotions
        self.prompts = prompts
        self.title = title
        self.episode = nil
        self.onSave = onSave
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()
    
    private func colorForEmotion(_ emotion: String) -> Color {
        switch emotion {
        case "Anger":
            return .red
        case "Sadness":
            return .blue
        case "Fear":
            return .purple
        case "Anxiety":
            return .indigo
        case "Shame":
            return .brown
        case "Disgust":
            return .green
        case "Grief":
            return .teal
        case "Confusion":
            return .orange
        default:
            return .gray
        }
    }
    
    // Define the order of prompts and their associated check-ins
    private let promptOrder = [
        "Describe the episode",
        "How do you think you'll feel tomorrow?",
        "How do you think you'll feel about this in 2 weeks?",
        "What's the worst that can happen?",
        "How about in 3 months?"
        // The title is handled separately and not shown in the prompts section
    ]
    
    // Map prompts to their associated check-in types
    private let promptToCheckIn: [String: CheckInType] = [
        "How do you think you'll feel tomorrow?": .twentyFourHour,
        "How do you think you'll feel about this in 2 weeks?": .twoWeek,
        "How about in 3 months?": .threeMonth
    ]
    
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 24) {
                // Date and Title
                VStack(alignment: .leading, spacing: 8) {
                    Text(dateFormatter.string(from: episode?.date ?? Date()))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(title)
                        .font(.title)
                        .fontWeight(.bold)
                }
                
                // Notes section (only show if we have an episode)
                if let episode = episode {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Notes")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Button("Add Note") {
                                isShowingAddNote = true
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        
                        // Display existing notes using LazyVStack for better swipe gesture handling
                        LazyVStack(spacing: 12) {
                            ForEach(episode.notes.sorted(by: { $0.createdAt > $1.createdAt }), id: \.createdAt) { note in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(note.createdAt, format: .dateTime.month().day().year().hour().minute())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text(note.text)
                                        .font(.body)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                                .contextMenu {
                                    Button("Edit") {
                                        editingNote = note
                                    }
                                    
                                    Button("Delete", role: .destructive) {
                                        deleteNote(note)
                                    }
                                }
                                .onTapGesture {
                                    // Double tap to edit as alternative
                                }
                                .onLongPressGesture(minimumDuration: 0.5) {
                                    editingNote = note
                                }
                            }
                        }
                        .id(refreshID) // Force refresh when this changes
                    }
                }
                
                Divider()
                
                // Emotions
                VStack(alignment: .leading, spacing: 16) {
                    Text("Emotions")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(emotions.sorted(by: { $0.value > $1.value })), id: \.key) { emotion, rating in
                            if rating > 0 {
                                EmotionBarView(emotion: emotion, rating: rating, color: colorForEmotion(emotion))
                            }
                        }
                    }
                }
                
                Divider()
                
                // Prompts and Responses in desired order
                VStack(alignment: .leading, spacing: 24) {
                    // First, show prompts in the defined order (if they exist)
                    let orderedPrompts = promptOrder.compactMap { promptKey in
                        prompts[promptKey] != nil ? promptKey : nil
                    }
                    
                    ForEach(Array(orderedPrompts.enumerated()), id: \.offset) { index, promptKey in
                        if let response = prompts[promptKey] {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(promptKey)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                
                                Text(response)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                
                                // Add check-in section if this prompt has an associated check-in
                                if let checkInType = promptToCheckIn[promptKey], let episode = episode {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Text(checkInType.displayName)
                                                .font(.headline)  // Smaller than title3
                                                .fontWeight(.medium)  // Less bold than semibold
                                            
                                            Spacer()
                                            
                                            if let existingCheckIn = episode.checkIn(for: checkInType) {
                                                // Show existing check-in, no add button
                                            } else if episode.isCheckInWindowActive(for: checkInType) {
                                                Button("Add Check-in") {
                                                    addingCheckInType = checkInType
                                                }
                                                .font(.subheadline)
                                                .foregroundColor(.blue)
                                            }
                                        }
                                        .padding(.top, 8)
                                        
                                        // Display existing check-in if it exists
                                        if let checkIn = episode.checkIn(for: checkInType) {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text(checkIn.createdAt, format: .dateTime.month().day().year().hour().minute())
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                
                                                Text(checkIn.text)
                                                    .font(.body)
                                            }
                                            .padding()
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(.secondarySystemBackground))
                                            .cornerRadius(12)
                                            .contextMenu {
                                                Button("Edit") {
                                                    editingCheckIn = checkIn
                                                }
                                                
                                                Button("Delete", role: .destructive) {
                                                    deleteCheckIn(checkIn)
                                                }
                                            }
                                            .onLongPressGesture(minimumDuration: 0.5) {
                                                editingCheckIn = checkIn
                                            }
                                        } else if !episode.isCheckInWindowActive(for: checkInType) && shouldShowEmptyCheckInSection(for: checkInType, episode: episode) {
                                            // Show placeholder text for check-ins that aren't available yet
                                            Text(checkInPlaceholderText(for: checkInType, episode: episode))
                                                .font(.body)
                                                .foregroundColor(.secondary)
                                                .italic()
                                                .padding()
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(Color(.secondarySystemBackground).opacity(0.5))
                                                .cornerRadius(12)
                                        }
                                    }
                                    .id(refreshID) // Force refresh when this changes
                                }
                            }
                            
                            // Add divider after each prompt except the last one
                            if index < orderedPrompts.count - 1 {
                                Divider()
                            }
                        }
                    }
                    
                    // Then show any remaining prompts (except the title prompt)
                    let remainingPrompts = Array(prompts.keys.sorted()).filter { key in
                        key != "Let's give this episode a title" && !promptOrder.contains(key)
                    }
                    
                    if !remainingPrompts.isEmpty && !orderedPrompts.isEmpty {
                        Divider()
                    }
                    
                    ForEach(Array(remainingPrompts.enumerated()), id: \.offset) { index, promptKey in
                        if let response = prompts[promptKey] {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(promptKey)
                                    .font(.headline)
                                
                                Text(response)
                                    .font(.body)
                            }
                            
                            // Add divider after each remaining prompt except the last one
                            if index < remainingPrompts.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationBarBackButtonHidden(onSave != nil)
        .toolbar {
            // Only show custom back button for episode creation flow (when onSave exists)
            if let onSave = onSave {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                    }
                    .fontWeight(.medium)
                }
            }
        }
        .sheet(isPresented: $isShowingAddNote, onDismiss: {
            // Refresh the notes list when returning from add note
            refreshID = UUID()
        }) {
            if let episode = episode {
                AddNoteView(episode: episode)
            }
        }
        .sheet(item: $editingNote, onDismiss: {
            // Refresh the notes list when returning from edit note
            refreshID = UUID()
        }) { note in
            EditNoteView(note: note)
        }
        .sheet(item: $addingCheckInType, onDismiss: {
            // Refresh when returning from add check-in
            refreshID = UUID()
        }) { checkInType in
            if let episode = episode {
                CheckInView(episode: episode, checkInType: checkInType)
            }
        }
        .sheet(item: $editingCheckIn, onDismiss: {
            // Refresh when returning from edit check-in
            refreshID = UUID()
        }) { checkIn in
            CheckInView(episode: episode!, checkInType: checkIn.checkInType, existingCheckIn: checkIn)
        }
    }
    
    @Environment(\.modelContext) private var modelContext
    
    private func deleteNote(_ note: EpisodeNote) {
        withAnimation {
            modelContext.delete(note)
        }
        // Trigger refresh after deletion
        refreshID = UUID()
    }
    
    private func deleteCheckIn(_ checkIn: CheckIn) {
        withAnimation {
            modelContext.delete(checkIn)
        }
        // Trigger refresh after deletion
        refreshID = UUID()
        
        // If the check-in is deleted, we might want to reschedule the notification
        // (in case user wants another chance to add the check-in)
        if let episode = episode {
            episode.scheduleNotifications()
        }
    }
    
    private func shouldShowEmptyCheckInSection(for checkInType: CheckInType, episode: Episode) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        switch checkInType {
        case .twentyFourHour:
            // Show section if it's not the day after the episode
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: episode.date),
                  let startOfNextDay = calendar.dateInterval(of: .day, for: nextDay)?.start,
                  let endOfNextDay = calendar.dateInterval(of: .day, for: nextDay)?.end else { return true }
            return now < startOfNextDay || now >= endOfNextDay
            
        case .twoWeek, .threeMonth:
            let targetDate = calendar.date(byAdding: .day, value: checkInType.daysFromEpisode, to: episode.date) ?? episode.date
            // Show the section if the target date hasn't arrived yet, or if it's been more than 24 hours past the target
            return now < targetDate || now > calendar.date(byAdding: .hour, value: 24, to: targetDate)!
        }
    }
    
    private func checkInPlaceholderText(for checkInType: CheckInType, episode: Episode) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        switch checkInType {
        case .twentyFourHour:
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: episode.date),
                  let startOfNextDay = calendar.dateInterval(of: .day, for: nextDay)?.start else {
                return "Check-in window has passed"
            }
            
            if now < startOfNextDay {
                if calendar.isDate(now, inSameDayAs: episode.date) {
                    return "Check-in available tomorrow"
                } else {
                    let formatter = RelativeDateTimeFormatter()
                    formatter.unitsStyle = .full
                    let timeUntil = formatter.localizedString(for: startOfNextDay, relativeTo: now)
                    return "Check-in available \(timeUntil)"
                }
            } else {
                return "Check-in window has passed"
            }
            
        case .twoWeek, .threeMonth:
            let targetDate = calendar.date(byAdding: .day, value: checkInType.daysFromEpisode, to: episode.date) ?? episode.date
            
            if now < targetDate {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .full
                let timeUntil = formatter.localizedString(for: targetDate, relativeTo: now)
                return "Check-in available \(timeUntil)"
            } else {
                return "Check-in window has passed"
            }
        }
    }
}

struct EmotionBarView: View {
    let emotion: String
    let rating: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(emotion)
                .font(.subheadline)
                .fontWeight(.medium)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    // Filled bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * (CGFloat(rating) / 5.0), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

#Preview {
    let episode = Episode(
        title: "Test Episode",
        emotions: ["Anger": 5, "Sadness": 3, "Fear": 2, "Anxiety": 4],
        prompts: [
            "Describe the episode": "I felt overwhelmed at work when...",
            "What triggered it?": "A deadline was moved up unexpectedly",
            "What do you need right now?": "Some time to breathe and reorganize",
            "Let's give this episode a title": "Unexpected deadline change"
        ]
    )
    
    return NavigationStack {
        EpisodeSummaryView(episode: episode)
    }
    .modelContainer(for: [Episode.self, EpisodeNote.self, CheckIn.self], inMemory: true)
}

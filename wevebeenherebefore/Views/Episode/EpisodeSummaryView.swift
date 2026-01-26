import SwiftUI
import SwiftData

enum SheetState: Identifiable {
    case addNote
    case editNote(EpisodeNote)
    case editCheckIn(CheckIn)
    case addCheckIn(CheckInType)
    case addSummary(Episode)
    case createMemoryFromSummary(String)

    var id: String {
        switch self {
        case .addNote:
            return "addNote"
        case .editNote(let note):
            return "editNote_\(note.createdAt.timeIntervalSince1970)"
        case .editCheckIn(let checkIn):
            return "editCheckIn_\(checkIn.createdAt.timeIntervalSince1970)"
        case .addCheckIn(let type):
            return "addCheckIn_\(type.rawValue)"
        case .addSummary:
            return "addSummary"
        case .createMemoryFromSummary:
            return "createMemoryFromSummary"
        }
    }
}

struct EpisodeSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let emotions: [String: Int]
    private let prompts: [String: String]
    private let title: String
    private let episode: Episode?
    private let onSave: (() -> Void)?
    
    @State private var sheetState: SheetState?
    
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
        "How about in 3 months?",
        "How will you feel 3 months from now?"
        // The title is handled separately and not shown in the prompts section
    ]
    
    // Map prompts to their associated check-in types
    private let promptToCheckIn: [String: CheckInType] = [
        "How do you think you'll feel tomorrow?": .twentyFourHour,
        "How do you think you'll feel about this in 2 weeks?": .twoWeek,
        "How about in 3 months?": .threeMonth,
        "How will you feel 3 months from now?": .threeMonth
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

                // Episode Summary section (only for existing episodes, available after 3 months)
                if let episode = episode {
                    if episode.canAddSummary || episode.hasSummary {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Episode Summary")
                                    .font(.title3)
                                    .fontWeight(.semibold)

                                Spacer()

                                if episode.hasSummary {
                                    Button("Edit") {
                                        sheetState = .addSummary(episode)
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                                }
                            }

                            if episode.hasSummary, let summary = episode.summary {
                                VStack(alignment: .leading, spacing: 12) {
                                    if let createdAt = episode.summaryCreatedAt {
                                        Text(createdAt, format: .dateTime.month().day().year())
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Text(summary)
                                        .font(.body)

                                    Button(action: {
                                        sheetState = .createMemoryFromSummary(summary)
                                    }) {
                                        HStack {
                                            Image(systemName: "heart.fill")
                                            Text("Create Memory")
                                        }
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                    }
                                    .padding(.top, 4)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                            } else {
                                Button(action: {
                                    sheetState = .addSummary(episode)
                                }) {
                                    Text("Add Summary")
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color.blue)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
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
                                sheetState = .addNote
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
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                                .contextMenu {
                                    Button("Edit") {
                                        sheetState = .editNote(note)
                                    }
                                    
                                    Button("Delete", role: .destructive) {
                                        deleteNote(note)
                                    }
                                }
                                .onTapGesture {
                                    // Double tap to edit as alternative
                                }
                                .onLongPressGesture(minimumDuration: 0.5) {
                                    sheetState = .editNote(note)
                                }
                            }
                        }
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
                            VStack(alignment: .leading, spacing: 16) {
                                // Prompt and response section
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(promptKey)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    
                                    Text(response)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                                
                                // Separate check-in section with additional spacing
                                if let checkInType = promptToCheckIn[promptKey], let episode = episode {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text(checkInType.displayName)
                                            .font(.headline)
                                            .fontWeight(.medium)
                                        
                                        // Primary check-in button when window is active and no existing check-in
                                        if episode.checkIn(for: checkInType) == nil && episode.isCheckInWindowActive(for: checkInType) {
                                            Button(action: {
                                                sheetState = .addCheckIn(checkInType)
                                            }) {
                                                Text("Add \(checkInType.displayName)")
                                                    .font(.body)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.white)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 12)
                                                    .background(Color.blue)
                                                    .cornerRadius(8)
                                            }
                                        }
                                        
                                        // Display existing check-in if it exists
                                        if let checkIn = episode.checkIn(for: checkInType) {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text(checkIn.createdAt, format: .dateTime.month().day().year().hour().minute())
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                
                                                Text(checkIn.text)
                                                    .font(.body)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .contextMenu {
                                                Button("Edit") {
                                                    sheetState = .editCheckIn(checkIn)
                                                }
                                                
                                                Button("Delete", role: .destructive) {
                                                    deleteCheckIn(checkIn)
                                                }
                                            }
                                            .onLongPressGesture(minimumDuration: 0.5) {
                                                sheetState = .editCheckIn(checkIn)
                                            }
                                        } else if !episode.isCheckInWindowActive(for: checkInType) && shouldShowEmptyCheckInSection(for: checkInType, episode: episode) {
                                            // Show disabled button for check-ins that aren't available yet
                                            Button(action: {
                                                // No action - disabled state
                                            }) {
                                                Text(checkInPlaceholderText(for: checkInType, episode: episode))
                                                    .font(.body)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.secondary)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 12)
                                                    .background(Color(.quaternarySystemFill))
                                                    .cornerRadius(8)
                                            }
                                            .disabled(true)
                                        }
                                    }
                                    .padding()
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
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
                                    .font(.title3)
                                    .fontWeight(.semibold)

                                Text(response)
                                    .font(.body)
                                    .foregroundColor(.secondary)
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
        .sheet(item: $sheetState) { state in
            switch state {
            case .addNote:
                if let episode = episode {
                    AddNoteView(episode: episode)
                }
            case .editNote(let note):
                EditNoteView(note: note)
            case .addCheckIn(let checkInType):
                if let episode = episode {
                    CheckInView(episode: episode, checkInType: checkInType)
                }
            case .editCheckIn(let checkIn):
                CheckInView(episode: episode!, checkInType: checkIn.checkInType, existingCheckIn: checkIn)
            case .addSummary(let episode):
                AddSummaryView(episode: episode)
            case .createMemoryFromSummary(let summaryText):
                AddMemoryView(initialText: summaryText)
            }
        }
    }
    
    @Environment(\.modelContext) private var modelContext
    
    private func deleteNote(_ note: EpisodeNote) {
        withAnimation {
            modelContext.delete(note)
            do {
                try modelContext.save()
            } catch {
                // Handle the error gracefully
                print("Error deleting note: \(error)")
                // You could show an alert to the user here
            }
        }
    }
    
    private func deleteCheckIn(_ checkIn: CheckIn) {
        withAnimation {
            modelContext.delete(checkIn)
            do {
                try modelContext.save()
            } catch {
                // Handle the error gracefully
                print("Error deleting check-in: \(error)")
                // You could show an alert to the user here
                return
            }
        }
        
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
            let windowEnd = calendar.date(byAdding: .hour, value: 24, to: targetDate) ?? targetDate
            return now < targetDate || now > windowEnd
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
                    let daysUntil = calendar.dateComponents([.day], from: now, to: startOfNextDay).day ?? 0
                    return "Check-in available in \(daysUntil) days"
                }
            } else {
                return "Check-in window has passed"
            }
            
        case .twoWeek, .threeMonth:
            let targetDate = calendar.date(byAdding: .day, value: checkInType.daysFromEpisode, to: episode.date) ?? episode.date
            
            if now < targetDate {
                // Calculate how many days LEFT until the check-in becomes available
                let daysLeft = calendar.dateComponents([.day], from: now, to: targetDate).day ?? 0
                
                if daysLeft <= 0 {
                    return "Check-in available now"
                } else if daysLeft == 1 {
                    return "Check-in available tomorrow"
                } else {
                    return "Check-in available in \(daysLeft) days"
                }
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
    let modelContainer = try! ModelContainer(for: Episode.self, EpisodeNote.self, CheckIn.self, configurations: .init(isStoredInMemoryOnly: true))
    
    // Create episode with all prompts including check-in prompts
    let episode = Episode(
        title: "Work Presentation Anxiety",
        emotions: ["Anxiety": 5, "Stress": 4, "Fear": 3, "Overwhelm": 4],
        prompts: [
            "Describe the episode": "I have a huge presentation tomorrow that I just found out about. My manager expects me to present our quarterly results to the entire leadership team. I feel completely unprepared and my hands are shaking just thinking about it.",
            "How do you think you'll feel tomorrow?": "I'm terrified I'll mess up the presentation and embarrass myself in front of everyone. I'll probably be anxious all night and feel even worse in the morning.",
            "How do you think you'll feel about this in 2 weeks?": "Hopefully by then I'll have gotten through it and learned that presentations aren't as scary as they seem. Maybe I'll even feel proud of myself for surviving it.",
            "What's the worst that can happen?": "I could completely freeze up, forget everything I wanted to say, and look incompetent in front of the leadership team. They might lose confidence in me and it could affect my career.",
            "How will you feel 3 months from now?": "This will probably just be another work challenge I overcame. I might even laugh about how anxious I was over something that turned out fine."
        ]
    )
    
    // Set episode date to 25 hours ago so 24h check-in window has passed
    let calendar = Calendar.current
    episode.date = calendar.date(byAdding: .hour, value: -25, to: Date()) ?? Date()
    
    // Add some notes
    let note1 = EpisodeNote(text: "Practiced the presentation three times and felt a bit more confident. Still nervous but manageable.", episode: episode)
    let note2 = EpisodeNote(text: "Remembered to use breathing techniques before the presentation. They really helped!", episode: episode)
    
    // Add a completed 24h check-in
    let checkIn24h = CheckIn(text: "The presentation went better than expected! I was still nervous but I got through it without major issues. My manager even complimented my data analysis. Feeling relieved and a bit proud of myself.", checkInType: .twentyFourHour, episode: episode)
    
    // Insert into model context
    modelContainer.mainContext.insert(episode)
    modelContainer.mainContext.insert(note1)
    modelContainer.mainContext.insert(note2)
    modelContainer.mainContext.insert(checkIn24h)
    
    try! modelContainer.mainContext.save()
    
    return NavigationStack {
        EpisodeSummaryView(episode: episode)
    }
    .modelContainer(modelContainer)
}

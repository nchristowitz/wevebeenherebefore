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
    
    private func fontSizeForRating(_ rating: Int) -> CGFloat {
        let baseFontSize: CGFloat = 14
        let scaleFactor: CGFloat = 1.5
        return baseFontSize * pow(scaleFactor, CGFloat(rating - 1))
    }
    
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
    
    // Define the order of prompts
    private let promptOrder = [
        "Describe the episode",
        "How do you think you'll feel tomorrow?",
        "How do you think you'll feel about this in 2 weeks?",
        "What's the worst that can happen?",
        "How about in 3 months?"
        // The title is handled separately and not shown in the prompts section
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
                
                // Check-ins sections (only show if we have an episode)
                if let episode = episode {
                    ForEach(CheckInType.allCases, id: \.self) { checkInType in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(checkInType.displayName)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                
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
                
                // Emotions
                VStack(alignment: .leading, spacing: 16) {
                    Text("Emotions")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    FlowLayout(spacing: 12) {
                        ForEach(Array(emotions.sorted(by: { $0.value > $1.value })), id: \.key) { emotion, rating in
                            if rating > 0 {
                                Text(emotion)
                                    .font(.system(size: fontSizeForRating(rating)))
                                    .fontWeight(.semibold)
                                    .foregroundColor(colorForEmotion(emotion))
                            }
                        }
                    }
                }
                
                // Prompts and Responses in desired order
                VStack(alignment: .leading, spacing: 24) {
                    // First, show prompts in the defined order (if they exist)
                    ForEach(promptOrder, id: \.self) { promptKey in
                        if let response = prompts[promptKey] {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(promptKey)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                
                                Text(response)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Then show any remaining prompts (except the title prompt)
                    ForEach(Array(prompts.keys.sorted()).filter { key in
                        key != "Let's give this episode a title" && !promptOrder.contains(key)
                    }, id: \.self) { promptKey in
                        if let response = prompts[promptKey] {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(promptKey)
                                    .font(.headline)
                                
                                Text(response)
                                    .font(.body)
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

// Helper view for flowing emotion tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return arrangeSubviews(sizes: sizes, proposal: proposal).size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let offsets = arrangeSubviews(sizes: sizes, proposal: proposal).offsets
        
        for (offset, subview) in zip(offsets, subviews) {
            subview.place(at: bounds.origin + offset, proposal: .unspecified)
        }
    }
    
    private func arrangeSubviews(sizes: [CGSize], proposal: ProposedViewSize) -> (offsets: [CGPoint], size: CGSize) {
        let width = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var currentPosition = CGPoint.zero
        var maxY: CGFloat = 0
        
        for size in sizes {
            if currentPosition.x + size.width > width && currentPosition.x > 0 {
                currentPosition.x = 0
                currentPosition.y = maxY + spacing
            }
            
            offsets.append(currentPosition)
            currentPosition.x += size.width + spacing
            maxY = max(maxY, currentPosition.y + size.height)
        }
        
        return (offsets, CGSize(width: width, height: maxY))
    }
}

// Replace the operator overload with an extension
extension CGPoint {
    static func + (left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x + right.x, y: left.y + right.y)
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

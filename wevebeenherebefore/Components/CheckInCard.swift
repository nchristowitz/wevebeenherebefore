import SwiftUI
import SwiftData

struct CheckInCard: View {
    let episode: Episode
    let checkInType: CheckInType
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    private var timeRemainingText: String {
        let calendar = Calendar.current
        let now = Date()
        let targetDate = calendar.date(byAdding: .day, value: checkInType.daysFromEpisode, to: episode.date) ?? episode.date
        let windowEnd = calendar.date(byAdding: .day, value: checkInType == .threeMonth ? 5 : 1, to: targetDate) ?? targetDate
        
        let components = calendar.dateComponents([.day, .hour], from: now, to: windowEnd)
        
        if let days = components.day, days > 0 {
            return "\(days) day\(days == 1 ? "" : "s") remaining"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s") remaining"
        } else {
            return "Available now"
        }
    }
    
    private var accessibilityLabel: String {
        return "\(checkInType.displayName) for episode \(episode.title), \(timeRemainingText)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(checkInType.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(episode.title)
                        .font(.subheadline)
                        .opacity(0.8)
                    
                    Text(timeRemainingText)
                        .font(.caption)
                        .opacity(0.6)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .opacity(0.7)
            }
            .padding(24)
        }
        .background(Color(.systemBackground))

        .cornerRadius(16)
        .shadow(color: .black.opacity(0.07), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDismiss()
            } label: {
                Label("Dismiss", systemImage: "xmark")
            }
            .accessibilityLabel("Dismiss check-in")
            .accessibilityHint("Hide this check-in reminder")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to start check-in. Swipe left to dismiss.")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    @Previewable @State var isPreview = true
    
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Episode.self, configurations: config)
    
    let sampleEpisode = Episode(
        title: "Difficult morning",
        emotions: ["anxious": 4, "overwhelmed": 3],
        prompts: ["What happened?": "Had a panic attack before work"]
    )
    container.mainContext.insert(sampleEpisode)
    
    return List {
        CheckInCard(
            episode: sampleEpisode,
            checkInType: .threeMonth,
            onTap: { print("Tapped") },
            onDismiss: { print("Dismissed") }
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        
        CheckInCard(
            episode: sampleEpisode,
            checkInType: .twentyFourHour,
            onTap: { print("Tapped 24h") },
            onDismiss: { print("Dismissed 24h") }
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        
        CheckInCard(
            episode: sampleEpisode,
            checkInType: .twoWeek,
            onTap: { print("Tapped 2w") },
            onDismiss: { print("Dismissed 2w") }
        )
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    .listStyle(.plain)
    .modelContainer(container)
}

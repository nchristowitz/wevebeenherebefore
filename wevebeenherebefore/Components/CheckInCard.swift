import SwiftUI
import SwiftData

struct CheckInCard: View {
    let episode: Episode
    let checkInType: CheckInType
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    private var timeRemainingText: String {
        guard let windowEnd = episode.checkInWindow(for: checkInType)?.end else {
            return "Available now"
        }

        let components = Calendar.current.dateComponents([.day, .hour], from: Date(), to: windowEnd)

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

    @Environment(\.colorScheme) private var colorScheme

    // One hue per time horizon, styled like the resilience cards. Fixed RGB
    // treated exactly like a card's chosen color: as-is in light mode, its
    // dark version (Color.darkCardVariant) in Dark Mode.
    private var accentColor: Color {
        switch checkInType {
        case .twentyFourHour: return Color(red: 1.0, green: 0.58, blue: 0.0)   // orange
        case .twoWeek: return Color(red: 0.19, green: 0.68, blue: 0.78)        // teal
        case .threeMonth: return Color(red: 0.35, green: 0.34, blue: 0.84)     // indigo
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(checkInType.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .opacity(0.7)

                Spacer()

                Text(timeRemainingText)
                    .font(.caption)
                    .opacity(0.7)
            }

            HStack(alignment: .center, spacing: 12) {
                Text(episode.title)
                    .font(.system(size: 24, weight: .semibold))
                    .kerning(-0.3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .opacity(0.8)
            }
        }
        .padding(20)
        .background(accentColor.cardColor(for: colorScheme))
        .cornerRadius(20)
        .foregroundColor(accentColor.cardTextColor(for: colorScheme))
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

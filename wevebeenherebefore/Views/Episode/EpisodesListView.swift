import SwiftUI
import SwiftData
import UserNotifications

struct EpisodesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Episode.createdAt, order: .reverse) private var episodes: [Episode]
    @ObservedObject private var notificationCoordinator = NotificationCoordinator.shared

    @State private var isShowingEpisodeFlow = false
    @State private var activeSheet: ActiveSheet?

    enum ActiveSheet: Identifiable {
        case checkIn(Episode, CheckInType)

        var id: String {
            "checkIn"
        }
    }

    // Group episodes by month and year
    private var groupedEpisodes: [(key: String, episodes: [Episode])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: episodes) { episode -> String in
            let components = calendar.dateComponents([.year, .month], from: episode.date)
            let date = calendar.date(from: components) ?? episode.date
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }

        // Sort by the most recent date in each group
        return grouped.map { (key: $0.key, episodes: $0.value) }
            .sorted { first, second in
                guard let firstDate = first.episodes.first?.date,
                      let secondDate = second.episodes.first?.date else {
                    return false
                }
                return firstDate > secondDate
            }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    ForEach(groupedEpisodes, id: \.key) { group in
                        Section(header: Text(group.key).font(.headline).textCase(nil)) {
                            ForEach(group.episodes) { episode in
                                NavigationLink(value: episode) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(episode.title)
                                                .font(.headline)

                                            Text(episode.date, format: .dateTime.month().day())
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.vertical, 4)

                                        Spacer()

                                        if episode.hasPendingCheckIn {
                                            NotificationDot()
                                        }
                                    }
                                }
                            }
                            .onDelete { offsets in
                                deleteEpisodesInGroup(group: group.episodes, offsets: offsets)
                            }
                        }
                    }
                }
                .navigationDestination(for: Episode.self) { episode in
                    EpisodeSummaryView(episode: episode)
                }

                // Floating '+' button for starting episode flow
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            isShowingEpisodeFlow = true
                        }) {
                            if #available(iOS 26.0, *) {
                                Image(systemName: "plus")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .frame(width: 60, height: 60)
                                    .glassEffect()
                            } else {
                                Image(systemName: "plus")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .frame(width: 60, height: 60)
                                    .background(
                                        Circle()
                                            .fill(.thickMaterial)
                                            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                                    )
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                        .accessibilityLabel("Start Episode")
                        .accessibilityHint("Begin tracking a new emotional episode")
                    }
                }
            }
            .navigationTitle("Episodes")
            .sheet(isPresented: $isShowingEpisodeFlow) {
                EpisodeFlowCoordinator()
                    .interactiveDismissDisabled()
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .checkIn(let episode, let checkInType):
                    CheckInView(episode: episode, checkInType: checkInType) {
                        activeSheet = nil
                        updateBadgeCount()
                    }
                }
            }
            .onAppear {
                // Handle deep link navigation from notifications
                if let navigation = notificationCoordinator.pendingNavigation {
                    handleNotificationNavigation(navigation)
                    notificationCoordinator.clearPendingNavigation()
                }
            }
            .onChange(of: notificationCoordinator.pendingNavigation) { _, pendingNav in
                // Handle deep link navigation from notifications
                if let navigation = pendingNav {
                    handleNotificationNavigation(navigation)
                    notificationCoordinator.clearPendingNavigation()
                }
            }
        }
    }
    
    private func deleteEpisodesInGroup(group: [Episode], offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let episode = group[index]
                // Cancel all notifications for this episode before deleting
                episode.cancelAllNotifications()
                modelContext.delete(episode)
            }

            do {
                try modelContext.save()
            } catch {
                print("Error deleting episodes: \(error)")
            }
        }
    }

    private func handleNotificationNavigation(_ navigation: NotificationCoordinator.PendingNavigation) {
        print("🔍 Handling notification navigation for episode: \(navigation.episodeID), checkIn: \(navigation.checkInType.displayName)")

        // Find the episode by ID
        let descriptor = FetchDescriptor<Episode>()

        do {
            let episodes = try modelContext.fetch(descriptor)

            print("🔍 Looking for episode ID: '\(navigation.episodeID)'")
            print("🔍 Available episodes: \(episodes.count)")

            // Try to find episode by converting both IDs to strings for comparison
            var foundEpisode: Episode?
            for episode in episodes {
                let episodeIDString = "\(episode.persistentModelID)"
                print("  - Episode '\(episode.title)': '\(episodeIDString)'")
                if episodeIDString == navigation.episodeID {
                    foundEpisode = episode
                    break
                }
            }

            if let episode = foundEpisode {
                // Check if this check-in already exists
                let existingCheckIn = episode.checkIns.first { $0.checkInType == navigation.checkInType }

                if existingCheckIn == nil {
                    print("✅ Found episode '\(episode.title)', navigating to \(navigation.checkInType.displayName) check-in")

                    // Navigate to check-in view
                    activeSheet = .checkIn(episode, navigation.checkInType)
                } else {
                    print("ℹ️ Check-in already completed for \(navigation.checkInType.displayName)")
                    // Still clear the badge since user interacted with the notification
                    updateBadgeCount()
                }
            } else {
                print("❌ Episode not found for ID: \(navigation.episodeID)")
            }
        } catch {
            print("❌ Error fetching episodes: \(error)")
        }
    }

    private func updateBadgeCount() {
        // Count pending check-ins across all episodes
        let descriptor = FetchDescriptor<Episode>()

        do {
            let episodes = try modelContext.fetch(descriptor)
            var pendingCount = 0

            for episode in episodes {
                let completedCheckInTypes = Set(episode.checkIns.map { $0.checkInType })
                for checkInType in CheckInType.allCases {
                    if !completedCheckInTypes.contains(checkInType) &&
                       !episode.isCheckInDismissed(for: checkInType) &&
                       episode.isCheckInWindowActive(for: checkInType) {
                        pendingCount += 1
                    }
                }
            }

            DispatchQueue.main.async {
                // Clear delivered notifications from notification center
                UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                // Update badge to reflect actual pending count
                UNUserNotificationCenter.current().setBadgeCount(pendingCount)
                print("📱 Updated badge count to: \(pendingCount)")
            }
        } catch {
            print("❌ Error updating badge count: \(error)")
            UNUserNotificationCenter.current().setBadgeCount(0)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Episode.self, configurations: config)
    
    // Create sample episodes
    let episode1 = Episode(
        title: "Stressful Day at Work",
        emotions: ["Stress": 8, "Fatigue": 7, "Frustration": 6],
        prompts: ["What happened?": "Had a difficult presentation that didn't go well", "How did I handle it?": "Took some deep breaths and talked to my colleague"]
    )
    episode1.date = Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
    
    let episode2 = Episode(
        title: "Anxiety Before Interview",
        emotions: ["Anxiety": 9, "Nervousness": 8],
        prompts: ["What triggered this?": "Job interview tomorrow", "What can I do?": "Practice breathing exercises and prepare more"]
    )
    episode2.date = Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date()
    
    let episode3 = Episode(
        title: "Feeling Overwhelmed",
        emotions: ["Overwhelm": 7, "Sadness": 5],
        prompts: ["What's causing this?": "Too many tasks at once", "What would help?": "Break things down into smaller steps"]
    )
    episode3.date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    
    let episode4 = Episode(
        title: "Panic Attack",
        emotions: ["Panic": 10, "Fear": 9, "Confusion": 7],
        prompts: ["Where was I?": "In the grocery store", "What helped?": "Found a quiet spot and used my breathing technique"]
    )
    episode4.date = Calendar.current.date(byAdding: .month, value: -2, to: Date()) ?? Date()
    
    // Insert episodes into the container
    container.mainContext.insert(episode1)
    container.mainContext.insert(episode2)
    container.mainContext.insert(episode3)
    container.mainContext.insert(episode4)
    
    return EpisodesListView()
        .modelContainer(container)
}

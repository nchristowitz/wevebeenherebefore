import SwiftUI
import SwiftData
import UserNotifications

struct EpisodesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Episode.createdAt, order: .reverse) private var episodes: [Episode]
    @ObservedObject private var notificationCoordinator = NotificationCoordinator.shared

    @State private var isShowingEpisodeFlow = false
    @State private var activeSheet: ActiveSheet?
    @State private var episodePendingDeletion: Episode?

    enum ActiveSheet: Identifiable {
        case checkIn(Episode, CheckInType)

        var id: String {
            "checkIn"
        }
    }

    struct PendingCheckIn: Identifiable {
        let episode: Episode
        let checkInType: CheckInType

        var id: String {
            "\(episode.uuid.uuidString)_\(checkInType.rawValue)"
        }
    }

    // Check-ins whose window is open now, soonest horizon first
    private var pendingCheckIns: [PendingCheckIn] {
        episodes.flatMap { episode in
            episode.pendingCheckInTypes.map { PendingCheckIn(episode: episode, checkInType: $0) }
        }
        .sorted { $0.checkInType.daysFromEpisode < $1.checkInType.daysFromEpisode }
    }

    // Group episodes by year, then month, so the list can show year dividers
    private var groupedByYear: [(year: String, months: [(key: String, episodes: [Episode])])] {
        let calendar = Calendar.current

        let byYear = Dictionary(grouping: episodes) { calendar.component(.year, from: $0.date) }

        return byYear.keys.sorted(by: >).map { year in
            let byMonth = Dictionary(grouping: byYear[year] ?? []) { calendar.component(.month, from: $0.date) }
            let months = byMonth.keys.sorted(by: >).map { month in
                (key: calendar.monthSymbols[month - 1], episodes: byMonth[month] ?? [])
            }
            return (year: String(year), months: months)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    // Open check-ins sit above the episode history
                    if !pendingCheckIns.isEmpty {
                        Section {
                            ForEach(pendingCheckIns) { checkIn in
                                CheckInCard(
                                    episode: checkIn.episode,
                                    checkInType: checkIn.checkInType,
                                    onTap: {
                                        activeSheet = .checkIn(checkIn.episode, checkIn.checkInType)
                                    },
                                    onDismiss: {
                                        dismissCheckIn(checkIn)
                                    }
                                )
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                    }

                    ForEach(groupedByYear, id: \.year) { yearGroup in
                        // Year divider splitting the episode history visually
                        Section {
                            HStack(spacing: 12) {
                                Text(yearGroup.year)
                                    .font(.title2)
                                    .fontWeight(.bold)

                                VStack { Divider() }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .accessibilityAddTraits(.isHeader)
                        }

                        ForEach(yearGroup.months, id: \.key) { group in
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
                                    .swipeActions(edge: .trailing) {
                                        // No destructive role: that removes the
                                        // row straight away, before the user confirms
                                        Button {
                                            episodePendingDeletion = episode
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .tint(.red)
                                    }
                                }
                            }
                        }
                    }
                }
                // Room below the last row so the floating '+' never covers it
                .contentMargins(.bottom, 88, for: .scrollContent)
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
                            Image(systemName: "plus")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .frame(width: 60, height: 60)
                                .glassEffect()
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
            .alert(
                "Delete this episode?",
                isPresented: Binding(
                    get: { episodePendingDeletion != nil },
                    set: { if !$0 { episodePendingDeletion = nil } }
                ),
                presenting: episodePendingDeletion
            ) { episode in
                Button("Delete", role: .destructive) {
                    deleteEpisode(episode)
                }
                Button("Cancel", role: .cancel) { }
            } message: { episode in
                Text("\"\(episode.title)\" and all its notes, check-ins and summary will be permanently deleted.")
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
    
    private func deleteEpisode(_ episode: Episode) {
        withAnimation {
            // Cancel all notifications for this episode before deleting
            episode.cancelAllNotifications()
            modelContext.delete(episode)

            do {
                try modelContext.save()
            } catch {
                print("Error deleting episode: \(error)")
            }
        }
        // Its pending check-ins no longer count towards the badge
        updateBadgeCount()
    }

    private func dismissCheckIn(_ checkIn: PendingCheckIn) {
        checkIn.episode.dismissCheckIn(for: checkIn.checkInType)
        do {
            try modelContext.save()
            updateBadgeCount()
        } catch {
            print("Error dismissing check-in: \(error)")
        }
    }

    private func handleNotificationNavigation(_ navigation: NotificationCoordinator.PendingNavigation) {
        print("🔍 Handling notification navigation for episode: \(navigation.episodeID), checkIn: \(navigation.checkInType.displayName)")

        // Find the episode by ID
        let descriptor = FetchDescriptor<Episode>()

        do {
            let episodes = try modelContext.fetch(descriptor)

            // Match by stable UUID; fall back to the legacy persistentModelID
            // format for notifications scheduled before the UUID migration
            let foundEpisode = episodes.first { $0.uuid.uuidString == navigation.episodeID }
                ?? episodes.first { "\($0.persistentModelID)" == navigation.episodeID }

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
        NotificationManager.shared.refreshBadgeCount(modelContext: modelContext)
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

    let episode5 = Episode(
        title: "Argument That Lingered",
        emotions: ["Anger": 6, "Sadness": 4],
        prompts: ["What happened?": "A disagreement that spiraled", "What helped?": "Time and a long walk"]
    )
    episode5.date = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    
    // Insert episodes into the container
    container.mainContext.insert(episode1)
    container.mainContext.insert(episode2)
    container.mainContext.insert(episode3)
    container.mainContext.insert(episode4)
    container.mainContext.insert(episode5)
    
    return EpisodesListView()
        .modelContainer(container)
}

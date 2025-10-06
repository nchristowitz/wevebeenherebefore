import SwiftUI
import SwiftData

struct EpisodesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Episode.createdAt, order: .reverse) private var episodes: [Episode]
    @Environment(\.dismiss) private var dismiss

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
            .navigationTitle("My Episodes")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
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

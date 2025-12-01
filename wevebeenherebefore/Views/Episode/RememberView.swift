import SwiftUI
import SwiftData

struct RememberView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Episode.createdAt, order: .reverse) private var allEpisodes: [Episode]

    let currentEpisode: Episode
    let onComplete: () -> Void

    @State private var opacity: Double = 0

    // All past episodes (excluding current)
    private var pastEpisodes: [Episode] {
        allEpisodes.filter { $0.persistentModelID != currentEpisode.persistentModelID }
    }

    // Group episodes by month and year (same as EpisodesListView)
    private var groupedEpisodes: [(key: String, episodes: [Episode])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: pastEpisodes) { episode -> String in
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
                if pastEpisodes.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "heart.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("Your journey starts here")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Complete more episodes to see your growth over time.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    List {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("We've Been Here Before, Remember?")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

                            Text("You've navigated difficult moments before.")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                        // Episodes grouped by month
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
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .navigationDestination(for: Episode.self) { episode in
                        EpisodeSummaryView(episode: episode)
                    }
                    .safeAreaInset(edge: .bottom) {
                        // Spacer for Continue button
                        Color.clear.frame(height: 80)
                    }
                }

                // Continue button - iOS 26 liquid glass style
                VStack {
                    Spacer()
                    HStack {
                        if #available(iOS 26.0, *) {
                            Button(action: {
                                onComplete()
                            }) {
                                Text("Continue")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .glassEffect()
                            }
                        } else {
                            Button(action: {
                                onComplete()
                            }) {
                                Text("Continue")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.thickMaterial)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onComplete()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
            }
            .opacity(opacity)
            .onAppear {
                // Gentle fade in
                withAnimation(.easeIn(duration: 0.5)) {
                    opacity = 1.0
                }
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Episode.self, Card.self, CheckIn.self, configurations: config)

    // Create sample episode
    let episode = Episode(
        title: "Test Episode",
        emotions: ["Anxiety": 4],
        prompts: ["What happened?": "Test"]
    )

    // Create past episode with check-in
    let pastEpisode = Episode(
        title: "Work Stress",
        emotions: ["Stress": 8],
        prompts: ["What happened?": "Big presentation"]
    )
    pastEpisode.date = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()

    let checkIn = CheckIn(
        text: "Looking back, that presentation went better than I thought. I survived it and learned a lot about handling pressure.",
        checkInType: .threeMonth,
        episode: pastEpisode
    )

    // Create sample cards
    let card1 = Card(text: "Deep breathing helps me calm down", type: .technique, color: .blue)
    let card2 = Card(text: "Watching the sunset from my window", type: .delight, color: .orange)

    container.mainContext.insert(pastEpisode)
    container.mainContext.insert(checkIn)
    container.mainContext.insert(card1)
    container.mainContext.insert(card2)

    return RememberView(currentEpisode: episode) {
        print("Completed")
    }
    .modelContainer(container)
}

import SwiftUI
import SwiftData

struct RememberView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Episode.createdAt, order: .reverse) private var allEpisodes: [Episode]

    let currentEpisode: Episode
    let onComplete: () -> Void

    @State private var opacity: Double = 0
    @State private var currentIndex: Int = 0
    @State private var shuffledEpisodes: [Episode] = []

    // Episodes with summaries (excluding current)
    private var summarizedEpisodes: [Episode] {
        allEpisodes.filter { episode in
            episode.persistentModelID != currentEpisode.persistentModelID && episode.hasSummary
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if summarizedEpisodes.isEmpty {
                    // Empty state - shouldn't normally be shown since coordinator skips this
                    VStack(spacing: 16) {
                        Image(systemName: "heart.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("Your journey starts here")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("As you reflect on past episodes, their summaries will appear here.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    VStack(spacing: 0) {
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
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                        // Carousel
                        TabView(selection: $currentIndex) {
                            ForEach(Array(shuffledEpisodes.enumerated()), id: \.element.id) { index, episode in
                                EpisodeSummaryCard(episode: episode)
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .automatic))

                        // Spacer for continue button
                        Color.clear.frame(height: 80)
                    }
                }

                // Continue button
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
                if shuffledEpisodes.isEmpty {
                    shuffledEpisodes = summarizedEpisodes.shuffled()
                }
                withAnimation(.easeIn(duration: 0.5)) {
                    opacity = 1.0
                }
            }
        }
    }
}

// Card view for episode summaries in carousel
struct EpisodeSummaryCard: View {
    let episode: Episode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(episode.title)
                .font(.title2)
                .fontWeight(.semibold)

            Text(episode.date, format: .dateTime.month().day().year())
                .font(.subheadline)
                .opacity(0.7)

            if let summary = episode.summary {
                Text(summary)
                    .font(.body)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Episode.self, Card.self, CheckIn.self, configurations: config)

    // Create current episode
    let episode = Episode(
        title: "Test Episode",
        emotions: ["Anxiety": 4],
        prompts: ["What happened?": "Test"]
    )

    // Create past episode with summary
    let pastEpisode = Episode(
        title: "Work Stress",
        emotions: ["Stress": 8],
        prompts: ["What happened?": "Big presentation"]
    )
    pastEpisode.date = Calendar.current.date(byAdding: .month, value: -4, to: Date()) ?? Date()
    pastEpisode.summary = "Looking back, that presentation went better than I thought. I survived it and learned a lot about handling pressure. The anxiety I felt beforehand was much worse than the actual experience."
    pastEpisode.summaryCreatedAt = Date()

    // Create another past episode with summary
    let pastEpisode2 = Episode(
        title: "Family Conflict",
        emotions: ["Sadness": 6],
        prompts: ["What happened?": "Argument with sibling"]
    )
    pastEpisode2.date = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    pastEpisode2.summary = "We eventually talked it out and our relationship is stronger now. These conflicts, while painful, can lead to better understanding."
    pastEpisode2.summaryCreatedAt = Date()

    container.mainContext.insert(pastEpisode)
    container.mainContext.insert(pastEpisode2)

    return RememberView(currentEpisode: episode) {
        print("Completed")
    }
    .modelContainer(container)
}

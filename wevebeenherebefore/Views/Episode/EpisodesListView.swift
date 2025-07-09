import SwiftUI
import SwiftData

struct EpisodesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Episode.createdAt, order: .reverse) private var episodes: [Episode]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(episodes) { episode in
                    NavigationLink(value: episode) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(episode.title)
                                    .font(.headline)

                                Text(episode.date, format: .dateTime.month().day().year())
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
                .onDelete(perform: deleteEpisodes)
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
    
    private func deleteEpisodes(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let episode = episodes[index]
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

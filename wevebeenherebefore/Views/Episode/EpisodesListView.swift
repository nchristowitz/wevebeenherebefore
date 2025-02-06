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
                    NavigationLink(destination: EpisodeSummaryView(
                        emotions: episode.emotions,
                        prompts: episode.prompts,
                        title: episode.title,
                        onSave: {}
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(episode.title)
                                .font(.headline)
                            
                            Text(episode.date, format: .dateTime.month().day().year())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: deleteEpisodes)
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
                modelContext.delete(episodes[index])
            }
        }
    }
} 
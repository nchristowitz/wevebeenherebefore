import SwiftUI
import SwiftData

struct AddSummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    let episode: Episode

    @State private var summaryText: String = ""

    init(episode: Episode) {
        self.episode = episode
        _summaryText = State(initialValue: episode.summary ?? "")
    }

    private var isEditing: Bool {
        episode.hasSummary
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isEditing ? "Edit summary" : "Add summary")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.leading, 5)
                        .padding(.top)
                }

                TextEditor(text: $summaryText)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .font(.system(size: 24, weight: .regular, design: .default))
                    .overlay(
                        Group {
                            if summaryText.isEmpty {
                                Text("Looking back, what did you learn from this episode?")
                                    .font(.system(size: 24, weight: .regular, design: .default))
                                    .foregroundColor(.primary.opacity(0.5))
                                    .allowsHitTesting(false)
                                    .padding(.leading, 5)
                                    .padding(.top, 8)
                            }
                        },
                        alignment: .topLeading
                    )

                Spacer()
            }
            .padding(.horizontal)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSummary()
                    }
                    .disabled(summaryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            isFocused = true
        }
    }

    private func saveSummary() {
        let trimmedText = summaryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        do {
            episode.summary = trimmedText
            if episode.summaryCreatedAt == nil {
                episode.summaryCreatedAt = Date()
            }

            try modelContext.save()
            dismiss()
        } catch {
            print("Error saving summary: \(error)")
            dismiss()
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Episode.self, configurations: config)

    let episode = Episode(
        title: "Work Stress Episode",
        emotions: ["Anxiety": 4],
        prompts: ["Describe the episode": "Test"]
    )
    // Set date to 100 days ago so summary is available
    episode.date = Calendar.current.date(byAdding: .day, value: -100, to: Date()) ?? Date()
    container.mainContext.insert(episode)

    return AddSummaryView(episode: episode)
        .modelContainer(container)
}

import SwiftUI
import SwiftData

struct AddNoteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    let episode: Episode
    @State private var noteText: String = ""
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Add a note")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top)
                
                TextEditor(text: $noteText)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .font(.body)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                
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
                        saveNote()
                    }
                    .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Save") {
                        saveNote()
                    }
                    .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            isFocused = true
        }
        .saveErrorAlert($saveError)
    }

    private func saveNote() {
        let trimmedText = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        let note = EpisodeNote(text: trimmedText, episode: episode)
        modelContext.insert(note)

        // Save now rather than relying on autosave, so a failure is visible
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Error saving note: \(error)")
            modelContext.rollback()
            saveError = saveErrorMessage(for: error)
        }
    }
}

#Preview {
    let episode = Episode(
        title: "Test Episode",
        emotions: ["Anxiety": 3],
        prompts: ["Test": "Test response"]
    )
    
    return AddNoteView(episode: episode)
        .modelContainer(for: [Episode.self, EpisodeNote.self], inMemory: true)
}

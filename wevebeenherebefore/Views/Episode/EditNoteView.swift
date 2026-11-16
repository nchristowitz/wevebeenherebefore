import SwiftUI
import SwiftData

struct EditNoteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    let note: EpisodeNote
    @State private var noteText: String = ""
    @State private var saveError: String?

    init(note: EpisodeNote) {
        self.note = note
        _noteText = State(initialValue: note.text)
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Edit note")
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

        note.text = trimmedText

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
    
    let note = EpisodeNote(text: "Sample note text", episode: episode)
    
    return EditNoteView(note: note)
        .modelContainer(for: [Episode.self, EpisodeNote.self], inMemory: true)
}

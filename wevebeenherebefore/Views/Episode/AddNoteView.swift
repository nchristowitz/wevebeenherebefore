import SwiftUI
import SwiftData

struct AddNoteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    let episode: Episode
    @State private var noteText: String = ""
    
    var body: some View {
        NavigationView {
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
                    .background(Color(.systemGray6))
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
    }
    
    private func saveNote() {
        let trimmedText = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        let note = EpisodeNote(text: trimmedText, episode: episode)
        modelContext.insert(note)
        
        dismiss()
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

//
//  EditNoteView.swift
//  wevebeenherebefore
//
//  Created by Nicholas Christowitz on 26.05.25.
//

import SwiftUI
import SwiftData

struct EditNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    let note: EpisodeNote
    @State private var noteText: String = ""
    
    init(note: EpisodeNote) {
        self.note = note
        _noteText = State(initialValue: note.text)
    }
    
    var body: some View {
        NavigationView {
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
        
        note.text = trimmedText
        
        dismiss()
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

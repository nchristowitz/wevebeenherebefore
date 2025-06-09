import SwiftUI
import SwiftData

struct CheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    let episode: Episode
    let checkInType: CheckInType
    let existingCheckIn: CheckIn?
    
    @State private var checkInText: String = ""
    
    init(episode: Episode, checkInType: CheckInType, existingCheckIn: CheckIn? = nil) {
        self.episode = episode
        self.checkInType = checkInType
        self.existingCheckIn = existingCheckIn
        _checkInText = State(initialValue: existingCheckIn?.text ?? "")
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isEditing ? "Edit \(checkInType.displayName.lowercased())" : "Add \(checkInType.displayName.lowercased())")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    Text(placeholderText)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                }
                
                TextEditor(text: $checkInText)
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
                        saveCheckIn()
                    }
                    .disabled(checkInText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Save") {
                        saveCheckIn()
                    }
                    .disabled(checkInText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            isFocused = true
        }
    }
    
    private var isEditing: Bool {
        existingCheckIn != nil
    }
    
    private var placeholderText: String {
        switch checkInType {
        case .twentyFourHour:
            return "How are you feeling compared to yesterday? Does this match what you expected?"
        case .twoWeek:
            return "Looking back at this episode after 2 weeks, how do you feel about it now?"
        case .threeMonth:
            return "After 3 months, what's your perspective on this episode? Has it affected you as much as you thought it would?"
        }
    }
    
    private func saveCheckIn() {
        let trimmedText = checkInText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        if let existingCheckIn = existingCheckIn {
            existingCheckIn.text = trimmedText
        } else {
            let checkIn = CheckIn(text: trimmedText, checkInType: checkInType, episode: episode)
            modelContext.insert(checkIn)
            
            // Cancel the notification for this check-in type
            episode.cancelNotificationForCheckIn(checkInType)
        }
        
        dismiss()
    }
}

#Preview {
    let episode = Episode(
        title: "Test Episode",
        emotions: ["Anxiety": 3],
        prompts: ["Test": "Test response"]
    )
    
    return CheckInView(episode: episode, checkInType: .twentyFourHour)
        .modelContainer(for: [Episode.self, CheckIn.self], inMemory: true)
}

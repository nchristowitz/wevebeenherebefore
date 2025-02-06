import SwiftUI

struct EpisodePromptView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    let prompt: EpisodePrompt
    @Binding var text: String
    let onNext: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(prompt.question)
                .font(.title)
                .fontWeight(.bold)
                .padding(.top)
            
            Text(prompt.placeholder)
                .font(.body)
                .foregroundColor(.secondary)
            
            TextEditor(text: $text)
                .focused($isFocused)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button(prompt.isLast ? "Done" : "Next") {
                            onNext()
                        }
                        .disabled(text.isEmpty)
                    }
                }
        }
        .padding(.horizontal)
        .navigationBarBackButtonHidden(false) // Show default back button
        .onAppear {
            isFocused = true
        }
    }
}

// Define the prompts structure
struct EpisodePrompt: Identifiable, Equatable {
    let id: Int
    let question: String
    let placeholder: String
    var isLast: Bool
    
    static func == (lhs: EpisodePrompt, rhs: EpisodePrompt) -> Bool {
        lhs.id == rhs.id
    }
    
    static let prompts: [EpisodePrompt] = [
        EpisodePrompt(
            id: 0,
            question: "Describe the episode",
            placeholder: "Think about future you as you write this, keep it short but detailed enough",
            isLast: false
        ),
        EpisodePrompt(
            id: 1,
            question: "How do you think you'll feel about this in 2 weeks?",
            placeholder: "Try to imagine yourself looking back at this moment",
            isLast: false
        ),
        EpisodePrompt(
            id: 2,
            question: "How about in 3 months?",
            placeholder: "Think about the bigger picture",
            isLast: false
        ),
        EpisodePrompt(
            id: 3,
            question: "Let's give this episode a title",
            placeholder: "Keep it short but recognizable for future you",
            isLast: true
        )
    ]
}

#Preview {
    NavigationStack {
        EpisodePromptView(
            prompt: EpisodePrompt.prompts[0],
            text: .constant(""),
            onNext: {}
        )
    }
} 
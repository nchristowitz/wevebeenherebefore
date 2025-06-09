import SwiftUI

struct EpisodePromptView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    let prompt: EpisodePrompt
    @Binding var text: String
    let onNext: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text(prompt.question)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(prompt.placeholder)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            TextEditor(text: $text)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .font(.body)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
            Spacer()
        }
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
        .navigationBarBackButtonHidden(false)
        .onAppear {
            isFocused = true
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                HStack {
                    Spacer()
                    Button(prompt.isLast ? "Done" : "Next") {
                        onNext()
                    }
                    .disabled(text.isEmpty)
                    .frame(minWidth: 60)
                }
            }
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
                question: "How do you think you'll feel tomorrow?",
                placeholder: "Sometimes the immediate future feels scarier than it actually is",
                isLast: false
            ),
            EpisodePrompt(
                id: 2,
                question: "How do you think you'll feel about this in 2 weeks?",
                placeholder: "Try to imagine yourself looking back at this moment",
                isLast: false
            ),
            EpisodePrompt(
                id: 3,
                question: "What's the worst that can happen?",
                placeholder: "What's the nuclear option? Play it out in your mind.",
                isLast: false
            ),
            EpisodePrompt(
                id: 4,
                question: "How about in 3 months?",
                placeholder: "Think about the bigger picture",
                isLast: false
            ),
            EpisodePrompt(
                id: 5,
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

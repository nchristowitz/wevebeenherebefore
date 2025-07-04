import SwiftUI

struct EpisodeTitlePromptView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    let prompt: EpisodePrompt
    @Binding var text: String
    let onNext: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(prompt.question)
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.leading, 5)
                    .padding(.top, 4)
            }
            
            TextEditor(text: $text)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .background(.clear)
                .font(.system(size: 24, weight: .regular, design: .default))
                .overlay(
                    Group {
                        if text.isEmpty {
                            Text(prompt.placeholder)
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
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
        .navigationBarBackButtonHidden(false)
        .onAppear {
            // Delay focus to avoid keyboard animation issues
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
        .onDisappear {
            // Ensure keyboard is dismissed properly
            isFocused = false
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                HStack {
                    Spacer()
                    Button("Done") {
                        onNext()
                    }
                    .disabled(text.isEmpty)
                    .frame(minWidth: 60)
                }
            }
        }
    }
}

#Preview("Empty Title") {
    NavigationStack {
        EpisodeTitlePromptView(
            prompt: EpisodePrompt(
                id: 5,
                question: "Let's give this episode a title",
                placeholder: "Keep it short but recognizable for future you",
                isLast: true
            ),
            text: .constant(""),
            onNext: { }
        )
    }
}

#Preview("With Text") {
    NavigationStack {
        EpisodeTitlePromptView(
            prompt: EpisodePrompt(
                id: 5,
                question: "Let's give this episode a title",
                placeholder: "Keep it short but recognizable for future you",
                isLast: true
            ),
            text: .constant("Overwhelming Deadline Crisis"),
            onNext: { }
        )
    }
}

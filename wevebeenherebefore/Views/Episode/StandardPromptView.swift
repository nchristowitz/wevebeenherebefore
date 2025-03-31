import SwiftUI

struct StandardPromptView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    let prompt: EpisodePrompt
    @Binding var text: String
    let onNext: () -> Void
    let isFixedHeight: Bool
    
    init(prompt: EpisodePrompt, text: Binding<String>, onNext: @escaping () -> Void, isFixedHeight: Bool = false) {
        self.prompt = prompt
        self._text = text
        self.onNext = onNext
        self.isFixedHeight = isFixedHeight
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(prompt.question)
                .font(.title)
                .fontWeight(.bold)
                .padding(.top)
            
            Text(prompt.placeholder)
                .font(.body)
                .foregroundColor(.secondary)
            
            if isFixedHeight {
                // Fixed height for titles
                TextEditor(text: $text)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .font(.body)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .frame(height: 80)
            } else {
                // Flexible height for regular prompts
                TextEditor(text: $text)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .font(.body)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .frame(minHeight: 200)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .navigationBarBackButtonHidden(false)
        .onAppear {
            isFocused = true
        }
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
} 
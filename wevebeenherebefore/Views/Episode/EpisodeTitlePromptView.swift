import SwiftUI

struct EpisodeTitlePromptView: View {
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
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity)
                .frame(height: 80) // Fixed height in separate frame modifier
                .font(.body)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            
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
                Button("Done") {
                    onNext()
                }
                .disabled(text.isEmpty)
            }
        }
    }
} 
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
            
            Text(prompt.placeholder)
                .font(.body)
                .foregroundColor(.secondary)
            
            TextEditor(text: $text)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .font(.body)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .frame(height: 80)
                
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

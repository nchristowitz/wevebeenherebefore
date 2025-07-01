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
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(prompt.question)
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top, 4)
            }
            
            if isFixedHeight {
                // Fixed height for titles
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
                    .frame(height: 80)
            } else {
                // Flexible height for regular prompts
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

#Preview {
    NavigationStack {
        StandardPromptView(
            prompt: EpisodePrompt.prompts[0],
            text: .constant(""),
            onNext: {}
        )
    }
}

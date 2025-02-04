import SwiftUI

struct CardTextEditor: View {
    @Binding var text: String
    let placeholder: String
    let textColor: Color
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        TextEditor(text: $text)
            .focused($isFocused)
            .scrollContentBackground(.hidden)
            .background(.clear)
            .frame(maxHeight: .infinity)
            .font(.system(size: 32, weight: .regular, design: .default))
            .foregroundColor(textColor)
            .overlay(
                Group {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 32, weight: .regular, design: .default))
                            .foregroundColor(textColor.opacity(0.5))
                            .allowsHitTesting(false)
                            .padding(.leading, 5)
                    }
                },
                alignment: .topLeading
            )
            .onAppear {
                isFocused = true
            }
    }
}

#Preview {
    CardTextEditor(
        text: .constant(""),
        placeholder: "Keep the delight short and sweet. E.g. The way my cat's fur feels under his neck.",
        textColor: .black
    )
    .padding()
    .background(Color.yellow.opacity(0.3))
} 
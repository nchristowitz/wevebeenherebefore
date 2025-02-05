import SwiftUI
import SwiftData

struct AddCardBaseView<Content: View>: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let type: CardType
    @State private var text: String = ""
    @Binding var selectedColor: Color
    @State private var selectedDate = Date()
    let imageData: Data?
    let content: () -> Content
    
    init(type: CardType, selectedColor: Binding<Color>, imageData: Data? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.type = type
        self._selectedColor = selectedColor
        self.imageData = imageData
        self.content = content
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                selectedColor
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if let imageData = imageData,
                               let uiImage = UIImage(data: imageData) {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxHeight: 200)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    
                                    Button(action: {
                                        // Handle image removal through parent view
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(.white, Color.black.opacity(0.5))
                                            .background(Circle().fill(.white))
                                            .offset(x: 8, y: -8)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            CardTextEditor(
                                text: $text,
                                placeholder: placeholderText,
                                textColor: textColor(for: selectedColor)
                            )
                            .frame(minHeight: 200)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    content()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(textColor(for: selectedColor))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCard()
                    }
                    .foregroundColor(textColor(for: selectedColor))
                }
            }
        }
    }
    
    private var placeholderText: String {
        switch type {
        case .memory:
            return "Briefly describe a memory that shows your resilience. E.g. I overcame my fear of failure and learned German."
        case .delight:
            return "Keep the delight short and sweet. E.g. The way my cat's fur feels under his neck."
        case .technique:
            return "What helps you in moments like this? E.g. Go for a long coffee walk"
        }
    }
    
    private func textColor(for backgroundColor: Color) -> Color {
        let components = UIColor(backgroundColor).cgColor.components ?? [0, 0, 0, 0]
        let brightness = ((components[0] * 299) + (components[1] * 587) + (components[2] * 114)) / 1000
        return brightness > 0.5 ? .black : .white
    }
    
    private func saveCard() {
        // Allow saving if there's text OR (it's a delight AND there's an image)
        guard !text.isEmpty || (type == .delight && imageData != nil) else { return }
        
        let card = Card(
            text: text,
            type: type,
            color: selectedColor,
            date: type == .memory ? selectedDate : nil,
            imageData: type == .delight ? imageData : nil
        )
        
        modelContext.insert(card)
        dismiss()
    }
}

// Helper extension to convert Color to hex string
extension Color {
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else { return nil }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX",
                     lroundf(r * 255),
                     lroundf(g * 255),
                     lroundf(b * 255))
    }
}

#Preview {
    AddCardBaseView(type: .delight, selectedColor: .constant(Color(uiColor: .systemGray6))) {
        EmptyView()
    }
} 
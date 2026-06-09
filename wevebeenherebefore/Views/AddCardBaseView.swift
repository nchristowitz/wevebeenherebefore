import SwiftUI
import SwiftData

struct AddCardBaseView<Content: View>: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let type: CardType
    @State private var text: String = ""
    @Binding var selectedColor: Color
    let date: Date?
    let imageData: Data?
    let onRemoveImage: (() -> Void)?
    let content: () -> Content
    let existingCard: Card?

    init(type: CardType, selectedColor: Binding<Color>, date: Date? = nil, imageData: Data? = nil, onRemoveImage: (() -> Void)? = nil, existingCard: Card? = nil, initialText: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.type = type
        self._selectedColor = selectedColor
        self.date = date
        self.imageData = imageData
        self.onRemoveImage = onRemoveImage
        self.existingCard = existingCard
        self.content = content

        if let card = existingCard {
            _text = State(initialValue: card.text)
        } else if let initialText = initialText {
            _text = State(initialValue: initialText)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                selectedColor
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if let imageData = imageData,
                       let uiImage = UIImage(data: imageData) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            if let onRemoveImage = onRemoveImage {
                                Button(action: onRemoveImage) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(.white, Color.black.opacity(0.5))
                                        .background(Circle().fill(.white))
                                        .offset(x: 8, y: -8)
                                }
                                .accessibilityLabel("Remove photo")
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }

                    CardTextEditor(
                        text: $text,
                        placeholder: AppConfig.cardPlaceholders[type] ?? "",
                        textColor: selectedColor.contrastingTextColor()
                    )
                    .padding(.horizontal)

                    content()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(selectedColor.contrastingTextColor())
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCard()
                    }
                    .foregroundColor(selectedColor.contrastingTextColor())
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
    
    
    private func saveCard() {
        guard !text.isEmpty || (type == .delight && imageData != nil) else { return }
        
        do {
            if let existingCard = existingCard {
                existingCard.text = text
                existingCard.color = selectedColor
                if type == .memory {
                    existingCard.date = date
                }
                if type == .delight {
                    existingCard.imageData = imageData
                }
            } else {
                let card = Card(
                    text: text,
                    type: type,
                    color: selectedColor,
                    date: type == .memory ? date : nil,
                    imageData: type == .delight ? imageData : nil
                )
                modelContext.insert(card)
            }
            
            try modelContext.save()
            dismiss()
        } catch {
            // Handle the error gracefully
            print("Error saving card: \(error)")
            // You could show an alert to the user here
        }
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


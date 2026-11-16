import SwiftUI
import SwiftData

struct AddCardBaseView<Content: View>: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let type: CardType
    @State private var text: String = ""
    @Binding var selectedColor: Color
    let date: Date?
    let imageData: Data?
    let song: CardSong?
    let onRemoveImage: (() -> Void)?
    let content: () -> Content
    let existingCard: Card?

    @State private var saveError: String?

    init(type: CardType, selectedColor: Binding<Color>, date: Date? = nil, imageData: Data? = nil, song: CardSong? = nil, onRemoveImage: (() -> Void)? = nil, existingCard: Card? = nil, initialText: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.type = type
        self._selectedColor = selectedColor
        self.date = date
        self.imageData = imageData
        self.song = song
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
        NavigationStack {
            ZStack {
                // Shows the card as it will look in the current appearance
                selectedColor.cardColor(for: colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if let imageData = imageData,
                       let uiImage = UIImage(data: imageData) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .dimmedInDarkMode()
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
                        textColor: selectedColor.cardTextColor(for: colorScheme)
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
                    .foregroundColor(selectedColor.cardTextColor(for: colorScheme))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCard()
                    }
                    .foregroundColor(selectedColor.cardTextColor(for: colorScheme))
                }

            }
        }
        .saveErrorAlert($saveError)
    }

    private var supportsSong: Bool {
        type == .delight || type == .memory
    }

    private func saveCard() {
        guard !text.isEmpty || (type == .delight && imageData != nil) || (supportsSong && song != nil) else { return }

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
                if supportsSong {
                    existingCard.song = song
                }
            } else {
                let card = Card(
                    text: text,
                    type: type,
                    color: selectedColor,
                    date: type == .memory ? date : nil,
                    imageData: type == .delight ? imageData : nil,
                    song: supportsSong ? song : nil
                )
                modelContext.insert(card)
            }
            
            try modelContext.save()
            dismiss()
        } catch {
            // Undo the unsaved insert/edit so a retry doesn't double up;
            // the editor stays open with everything intact
            print("Error saving card: \(error)")
            modelContext.rollback()
            saveError = saveErrorMessage(for: error)
        }
    }
}

#Preview {
    AddCardBaseView(type: .delight, selectedColor: .constant(Card.defaultColor)) {
        EmptyView()
    }
} 


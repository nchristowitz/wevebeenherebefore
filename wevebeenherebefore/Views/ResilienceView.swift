import SwiftUI
import SwiftData

enum FilterType {
    case memory
    case delight
    case technique
    case imagesOnly
    case dateOldest
}

struct ResilienceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Card.createdAt, order: .reverse) private var cards: [Card]

    @State private var selectedFilter: FilterType?
    @State private var editingCard: Card?
    @State private var cardPendingDeletion: Card?
    @State private var shuffledCardIDs: [PersistentIdentifier] = []
    @AppStorage("shuffleCardsEnabled") private var shuffleEnabled = false

    // Consolidated sheet state
    @State private var activeSheet: ActiveSheet?

    enum ActiveSheet: Identifiable {
        case delight(Card? = nil)
        case memory(Card? = nil)
        case technique(Card? = nil)

        var id: String {
            switch self {
            case .delight: return "delight"
            case .memory: return "memory"
            case .technique: return "technique"
            }
        }
    }
    
    var filteredCards: [Card] {
        // Start with base cards, applying shuffle if enabled
        var result: [Card]
        if shuffleEnabled && !shuffledCardIDs.isEmpty {
            // Sort by shuffled order
            let idToIndex = Dictionary(uniqueKeysWithValues: shuffledCardIDs.enumerated().map { ($1, $0) })
            result = cards.sorted { card1, card2 in
                let index1 = idToIndex[card1.persistentModelID] ?? Int.max
                let index2 = idToIndex[card2.persistentModelID] ?? Int.max
                return index1 < index2
            }
        } else {
            result = Array(cards)
        }

        // Apply filter if selected
        guard let filter = selectedFilter else { return result }

        switch filter {
        case .memory:
            return result.filter { $0.type == .memory }
        case .delight:
            return result.filter { $0.type == .delight }
        case .technique:
            return result.filter { $0.type == .technique }
        case .imagesOnly:
            return result.filter { $0.imageData != nil }
        case .dateOldest:
            return result.sorted { $0.createdAt < $1.createdAt }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main list content
                List {
                    ForEach(filteredCards) { card in
                        CardView(card: card)
                            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing) {
                                // No destructive role: that removes the row
                                // straight away, before the user confirms
                                Button {
                                    cardPendingDeletion = card
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                                .accessibilityLabel("Delete card")
                                .accessibilityHint("Permanently remove this \(card.type.rawValue) card")

                                Button {
                                    editingCard = card
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                                .accessibilityLabel("Edit card")
                                .accessibilityHint("Modify this \(card.type.rawValue) card")
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                // Room below the last card so the floating '+' never covers it
                .contentMargins(.bottom, 88, for: .scrollContent)

                // Floating '+' button for adding cards
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Menu {
                            Button(action: {
                                activeSheet = .delight()
                            }) {
                                Label("Add Delight", systemImage: "heart.fill")
                            }

                            Button(action: {
                                activeSheet = .memory()
                            }) {
                                Label("Add Memory", systemImage: "book")
                            }

                            Button(action: {
                                activeSheet = .technique()
                            }) {
                                Label("Add Technique", systemImage: "figure.mind.and.body")
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .frame(width: 60, height: 60)
                                .glassEffect()
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                        .accessibilityLabel("Add Card")
                        .accessibilityHint("Add a new resilience card")
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: {
                            selectedFilter = selectedFilter == .memory ? nil : .memory
                        }) {
                            if selectedFilter == .memory {
                                Label("Memories", systemImage: "checkmark")
                            } else {
                                Label("Memories", systemImage: "book")
                            }
                        }

                        Button(action: {
                            selectedFilter = selectedFilter == .delight ? nil : .delight
                        }) {
                            if selectedFilter == .delight {
                                Label("Delights", systemImage: "checkmark")
                            } else {
                                Label("Delights", systemImage: "heart.fill")
                            }
                        }

                        Button(action: {
                            selectedFilter = selectedFilter == .technique ? nil : .technique
                        }) {
                            if selectedFilter == .technique {
                                Label("Techniques", systemImage: "checkmark")
                            } else {
                                Label("Techniques", systemImage: "figure.mind.and.body")
                            }
                        }

                        Button(action: {
                            selectedFilter = selectedFilter == .imagesOnly ? nil : .imagesOnly
                        }) {
                            if selectedFilter == .imagesOnly {
                                Label("Images Only", systemImage: "checkmark")
                            } else {
                                Label("Images Only", systemImage: "photo")
                            }
                        }

                        Button(action: {
                            selectedFilter = selectedFilter == .dateOldest ? nil : .dateOldest
                        }) {
                            if selectedFilter == .dateOldest {
                                Label("Oldest First", systemImage: "checkmark")
                            } else {
                                Label("Oldest First", systemImage: "arrow.up.circle")
                            }
                        }

                        Divider()

                        Button(action: {
                            shuffleEnabled.toggle()
                            if shuffleEnabled {
                                shuffleCards()
                            }
                        }) {
                            if shuffleEnabled {
                                Label("Shuffle", systemImage: "checkmark")
                            } else {
                                Label("Shuffle", systemImage: "shuffle")
                            }
                        }

                        if selectedFilter != nil {
                            Divider()

                            Button(action: {
                                selectedFilter = nil
                            }) {
                                Label("Clear Filter", systemImage: "xmark.circle")
                            }
                        }
                    } label: {
                        Image(systemName: selectedFilter != nil ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("Filter")
                    .accessibilityHint("Filter resilience cards")
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .delight(let existingCard):
                    AddDelightView(existingCard: existingCard)
                case .memory(let existingCard):
                    AddMemoryView(existingCard: existingCard)
                case .technique(let existingCard):
                    AddTechniqueView(existingCard: existingCard)
                }
            }
            .alert(
                "Delete this card?",
                isPresented: Binding(
                    get: { cardPendingDeletion != nil },
                    set: { if !$0 { cardPendingDeletion = nil } }
                ),
                presenting: cardPendingDeletion
            ) { card in
                Button("Delete", role: .destructive) {
                    deleteCard(card)
                }
                Button("Cancel", role: .cancel) { }
            } message: { card in
                Text("This \(card.type.rawValue) will be permanently deleted.")
            }
            .onChange(of: editingCard) { _, card in
                if let card = card {
                    switch card.type {
                    case .memory:
                        activeSheet = .memory(card)
                    case .delight:
                        activeSheet = .delight(card)
                    case .technique:
                        activeSheet = .technique(card)
                    }
                    editingCard = nil
                }
            }
        }
        .onAppear {
            // Shuffle cards if enabled
            if shuffleEnabled {
                shuffleCards()
            }
        }
    }

    private func shuffleCards() {
        shuffledCardIDs = cards.map { $0.persistentModelID }.shuffled()
    }

    private func deleteCard(_ card: Card) {
        modelContext.delete(card)
        do {
            try modelContext.save()
        } catch {
            print("Error deleting card: \(error)")
        }
    }
}

struct CardView: View {
    let card: Card

    @Environment(\.colorScheme) private var colorScheme

    // Floating play/pause panel inset over the bottom of the card's image,
    // its corners concentric with the image's
    @ViewBuilder
    private func songPillOverlay(imageCornerRadius: CGFloat) -> some View {
        if let song = card.song {
            CardSongRow(
                song: song,
                style: .floating,
                floatingCornerRadius: max(imageCornerRadius - 8, 4)
            )
            .padding(8)
        }
    }

    private var accessibilityLabel: String {
        var components: [String] = []
        
        // Add card type
        components.append("\(card.type.rawValue.capitalized) card")
        
        // Add date for memories
        if card.type == .memory, let date = card.date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            components.append("from \(formatter.string(from: date))")
        }
        
        // Add text content
        if !card.text.isEmpty {
            components.append(card.text)
        }
        
        // Add image info
        if card.imageData != nil {
            components.append("includes image")
        }
        
        return components.joined(separator: ", ")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: -12) {
            if card.type == .memory, let date = card.date {
                Text(date, format: .dateTime.month().year())
                    .font(.caption)
                    .textCase(.uppercase)
                    .opacity(0.6)
                    .padding(.horizontal, 20)
                    .padding(.top)
                    .accessibilityLabel("Date: \(date, format: .dateTime.month().year())")
            }
            
            if let imageData = card.imageData,
               let uiImage = UIImage(data: imageData) {
                if card.text.isEmpty {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .dimmedInDarkMode()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(alignment: .bottom) { songPillOverlay(imageCornerRadius: 16) }
                        .accessibilityLabel("Card image")
                        .accessibilityHint("Resilience card image for \(card.type.rawValue)")
                } else {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .dimmedInDarkMode()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(alignment: .bottom) { songPillOverlay(imageCornerRadius: 8) }
                        .padding(.horizontal)
                        .padding(.top)
                        .accessibilityLabel("Card image")
                        .accessibilityHint("Supporting image for this \(card.type.rawValue)")
                }
            }

            if !card.text.isEmpty {
                Text(card.text)
                    // Photos take the lead on mixed cards; text drops to a caption size
                    .font(.system(size: card.imageData == nil ? 32 : 21, weight: .regular, design: .default))
                    .padding(20)
                    .kerning(-0.3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(card.text)
            }

            if let song = card.song, card.imageData == nil {
                CardSongRow(song: song)
                    .padding(.horizontal, 16)
                    .padding(.top, card.text.isEmpty ? 16 : 0)
                    .padding(.bottom, 16)
            }
        }
        .background(card.color.cardColor(for: colorScheme))
        .cornerRadius(20)
        .foregroundColor(card.color.cardTextColor(for: colorScheme))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to view actions. Swipe actions available.")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Card.self, configurations: config)
    
    // Create sample cards
    let sampleCards = [
        Card(text: "The way my cat's fur feels under his neck", type: .delight, color: .orange),
        Card(text: "I overcame my fear of failure and learned German", type: .memory, color: .blue, date: Date().addingTimeInterval(-86400 * 30)),
        Card(text: "Go for a long coffee walk", type: .technique, color: .green),
        Card(text: "Dancing in the kitchen while cooking dinner", type: .delight, color: .pink),
        Card(text: "The time I spoke up for myself at work and got promoted", type: .memory, color: .purple, date: Date().addingTimeInterval(-86400 * 60)),
        Card(text: "Take five deep breaths and count them slowly", type: .technique, color: .teal),
        Card(text: "Warm sunlight streaming through my window in the morning", type: .delight, color: .yellow),
        Card(text: "When I helped a stranger and realized how good it felt", type: .memory, color: .indigo, date: Date().addingTimeInterval(-86400 * 10))
    ]
    
    for card in sampleCards {
        container.mainContext.insert(card)
    }
    
    return ResilienceView()
        .modelContainer(container)
}

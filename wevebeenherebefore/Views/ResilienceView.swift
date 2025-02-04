import SwiftUI
import SwiftData

struct ResilienceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Card.createdAt, order: .reverse) private var cards: [Card]
    
    @State private var isShowingDelight = false
    @State private var isShowingMemory = false
    @State private var isShowingTechnique = false
    @State private var cardToDelete: Card?
    
    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    ForEach(cards) { card in
                        CardView(card: card)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 16)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    cardToDelete = card
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button {
                                    // TODO: Implement edit functionality
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
                .listStyle(.plain)
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        AddCardButton(
                            isShowingDelight: $isShowingDelight,
                            isShowingMemory: $isShowingMemory,
                            isShowingTechnique: $isShowingTechnique
                        )
                        .padding()
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $isShowingDelight) {
                AddDelightView()
            }
            .sheet(isPresented: $isShowingMemory) {
                AddMemoryView()
            }
            .sheet(isPresented: $isShowingTechnique) {
                AddTechniqueView()
            }
            .alert("Delete Card", isPresented: .init(
                get: { cardToDelete != nil },
                set: { if !$0 { cardToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    cardToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let card = cardToDelete {
                        modelContext.delete(card)
                        cardToDelete = nil
                    }
                }
            } message: {
                Text("Are you sure you want to delete this card?")
            }
        }
    }
}

struct CardView: View {
    let card: Card
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let imageData = card.imageData,
               let uiImage = UIImage(data: imageData) {
                if card.text.isEmpty {
                    // Photo only - fill entire card
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 720)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    // Photo with text - maintain padding
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 720)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal)
                        .padding(.top)
                }
            }
            
            if !card.text.isEmpty {
                Text(card.text)
                    .font(.system(size: 32, weight: .regular, design: .default))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(card.color)
        .cornerRadius(12)
        .foregroundColor(textColor(for: card.color))
    }
    
    private func textColor(for backgroundColor: Color) -> Color {
        let components = UIColor(backgroundColor).cgColor.components ?? [0, 0, 0, 0]
        let brightness = ((components[0] * 299) + (components[1] * 587) + (components[2] * 114)) / 1000
        return brightness > 0.5 ? .black : .white
    }
}

#Preview {
    ResilienceView()
        .modelContainer(for: Card.self, inMemory: true)
} 
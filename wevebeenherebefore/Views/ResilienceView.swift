import SwiftUI
import SwiftData

struct ResilienceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Card.createdAt, order: .reverse) private var cards: [Card]
    
    @State private var isShowingDelight = false
    @State private var isShowingMemory = false
    @State private var isShowingTechnique = false
    @State private var isShowingFilterMenu = false
    @State private var selectedFilter: FilterType?
    @State private var editingCard: Card?
    
    var filteredCards: [Card] {
        guard let filter = selectedFilter else { return cards }
        
        switch filter {
        case .memory:
            return cards.filter { $0.type == .memory }
        case .delight:
            return cards.filter { $0.type == .delight }
        case .technique:
            return cards.filter { $0.type == .technique }
        case .imagesOnly:
            return cards.filter { $0.imageData != nil }
        case .dateNewest:
            return cards.sorted { $0.createdAt > $1.createdAt }
        case .dateOldest:
            return cards.sorted { $0.createdAt < $1.createdAt }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    ForEach(filteredCards) { card in
                        CardView(card: card)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(card)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button {
                                    editingCard = card
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                
                VStack {
                    Spacer()
                    
                    if isShowingFilterMenu {
                        ScrollView(.horizontal, showsIndicators: false) {
                            FilterMenu(selectedFilter: $selectedFilter, isPresented: $isShowingFilterMenu)
                        }
                        .transition(.move(edge: .bottom))
                    }
                    
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.spring()) {
                                isShowingFilterMenu.toggle()
                            }
                        }) {
                            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.black)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding(.trailing)
                        
                        AddCardButton(
                            isShowingDelight: $isShowingDelight,
                            isShowingMemory: $isShowingMemory,
                            isShowingTechnique: $isShowingTechnique
                        )
                        .padding(.trailing)
                    }
                    .padding(.bottom)
                }
            }
            .sheet(isPresented: $isShowingDelight) {
                AddDelightView()
            }
            .sheet(isPresented: $isShowingMemory) {
                AddMemoryView()
            }
            .sheet(isPresented: $isShowingTechnique) {
                AddTechniqueView()
            }
            .sheet(item: $editingCard) { card in
                switch card.type {
                case .memory:
                    AddMemoryView()
                case .delight:
                    AddDelightView()
                case .technique:
                    AddTechniqueView()
                }
            }
        }
    }
}

struct CardView: View {
    let card: Card
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if card.type == .memory, let date = card.date {
                Text(date, format: .dateTime.month().year())
                    .font(.caption)
                    .textCase(.uppercase)
                    .opacity(0.5)
                    .padding(.horizontal)
                    .padding(.top)
            }
            
            if let imageData = card.imageData,
               let uiImage = UIImage(data: imageData) {
                if card.text.isEmpty {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
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
        .foregroundColor(card.color.contrastingTextColor())
    }
}

#Preview {
    ResilienceView()
        .modelContainer(for: Card.self, inMemory: true)
} 
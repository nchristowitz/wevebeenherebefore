import SwiftUI
import SwiftData

struct ResilienceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Card.createdAt, order: .reverse) private var cards: [Card]
    
    @State private var isShowingDelight = false
    @State private var isShowingMemory = false
    @State private var isShowingTechnique = false
    @State private var isShowingFilterMenu = false
    @State private var isShowingEpisodeFlow = false
    @State private var isShowingEpisodesList = false
    @State private var selectedFilter: FilterType?
    @State private var editingCard: Card?
    @State private var isShowingAddMenu = false
    @State private var isShowingEpisodeMenu = false
    
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
                // Main list content
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
                
                    // Bottom buttons
                    HStack(spacing: 24) {
                        CircularButton(systemImage: "line.3.horizontal.decrease") {
                            isShowingFilterMenu = true
                        }
                        
                        CircularButton(systemImage: "tornado") {
                            isShowingEpisodeMenu = true
                        }
                        
                        CircularButton(systemImage: "plus") {
                            isShowingAddMenu = true
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                
                // Menu trays (always in view hierarchy)
                MenuTray(title: "Filter by", isPresented: $isShowingFilterMenu) {
                    FilterMenu(selectedFilter: $selectedFilter, isPresented: $isShowingFilterMenu)
                }
                
                MenuTray(title: "Add a resilience card", isPresented: $isShowingAddMenu) {
                    AddCardMenu(
                        isShowingDelight: $isShowingDelight,
                        isShowingMemory: $isShowingMemory,
                        isShowingTechnique: $isShowingTechnique,
                        isPresented: $isShowingAddMenu
                    )
                }
                
                MenuTray(title: "Episodes", isPresented: $isShowingEpisodeMenu) {
                    EpisodeMenu(
                        isShowingEpisodeFlow: $isShowingEpisodeFlow,
                        isShowingEpisodeList: $isShowingEpisodesList,
                        isPresented: $isShowingEpisodeMenu
                    )
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
            .sheet(isPresented: $isShowingEpisodeFlow) {
                EpisodeFlowCoordinator()
                    .interactiveDismissDisabled()
            }
            .sheet(isPresented: $isShowingEpisodesList) {
                EpisodesListView()
            }
            .sheet(item: $editingCard) { card in
                switch card.type {
                case .memory:
                    AddMemoryView(existingCard: card)
                case .delight:
                    AddDelightView(existingCard: card)
                case .technique:
                    AddTechniqueView(existingCard: card)
                }
            }
        }
        .onAppear {
            // Check notification permissions on app launch
            Task {
                await NotificationManager.shared.checkPermission()
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

struct FilterMenuView: View {
    @Binding var selectedFilter: FilterType?
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            FilterMenu(selectedFilter: $selectedFilter, isPresented: $isPresented)
                .navigationTitle("Filter by")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct AddCardMenuView: View {
    @Binding var isShowingDelight: Bool
    @Binding var isShowingMemory: Bool
    @Binding var isShowingTechnique: Bool
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            AddCardMenu(
                isShowingDelight: $isShowingDelight,
                isShowingMemory: $isShowingMemory,
                isShowingTechnique: $isShowingTechnique,
                isPresented: $isPresented
            )
            .navigationTitle("Add a resilience card")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ResilienceView()
        .modelContainer(for: Card.self, inMemory: true)
}

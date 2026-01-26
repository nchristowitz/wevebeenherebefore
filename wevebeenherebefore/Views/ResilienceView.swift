import SwiftUI
import SwiftData

struct ResilienceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Card.createdAt, order: .reverse) private var cards: [Card]
    @Query private var episodes: [Episode]
    @ObservedObject private var notificationCoordinator = NotificationCoordinator.shared

    @State private var selectedFilter: FilterType?
    @State private var editingCard: Card?

    // Consolidated sheet state
    @State private var activeSheet: ActiveSheet?

    enum ActiveSheet: Identifiable {
        case delight(Card? = nil)
        case memory(Card? = nil)
        case technique(Card? = nil)
        case checkIn(Episode, CheckInType)

        var id: String {
            switch self {
            case .delight: return "delight"
            case .memory: return "memory"
            case .technique: return "technique"
            case .checkIn: return "checkIn"
            }
        }
    }
    
    // Check if there are pending check-ins
    private var hasPendingCheckIns: Bool {
        let descriptor = FetchDescriptor<Episode>()
        
        do {
            let episodes = try modelContext.fetch(descriptor)
            for episode in episodes {
                let completedCheckInTypes = Set(episode.checkIns.map { $0.checkInType })
                for checkInType in CheckInType.allCases {
                    if !completedCheckInTypes.contains(checkInType) && episode.isCheckInWindowActive(for: checkInType) {
                        return true
                    }
                }
            }
        } catch {
            print("Error checking for pending check-ins: \(error)")
        }
        return false
    }
    
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
    
    struct PendingCheckIn: Identifiable {
        let episode: Episode
        let checkInType: CheckInType
        
        var id: String {
            "\(episode.persistentModelID)_\(checkInType.rawValue)"
        }
    }
    
    var pendingCheckIns: [PendingCheckIn] {
        var pending: [PendingCheckIn] = []
        
        for episode in episodes {
            for checkInType in CheckInType.allCases {
                if episode.isCheckInWindowActive(for: checkInType) && 
                   !episode.hasCheckIn(for: checkInType) && 
                   !episode.isCheckInDismissed(for: checkInType) {
                    pending.append(PendingCheckIn(episode: episode, checkInType: checkInType))
                }
            }
        }
        
        return pending.sorted { first, second in
            first.checkInType.daysFromEpisode < second.checkInType.daysFromEpisode
        }
    }
    
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main list content
                List {
                    // Check-in cards at the top
                    ForEach(pendingCheckIns) { checkIn in
                        CheckInCard(
                            episode: checkIn.episode,
                            checkInType: checkIn.checkInType,
                            onTap: {
                                activeSheet = .checkIn(checkIn.episode, checkIn.checkInType)
                            },
                            onDismiss: {
                                checkIn.episode.dismissCheckIn(for: checkIn.checkInType)
                                do {
                                    try modelContext.save()
                                    updateBadgeCount()
                                } catch {
                                    print("Error dismissing check-in: \(error)")
                                }
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    // Regular resilience cards
                    ForEach(filteredCards) { card in
                        CardView(card: card)
                            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(card)
                                    do {
                                        try modelContext.save()
                                    } catch {
                                        print("Error deleting card: \(error)")
                                    }
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
                            if #available(iOS 26.0, *) {
                                Image(systemName: "plus")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .frame(width: 60, height: 60)
                                    .glassEffect()
                            } else {
                                Image(systemName: "plus")
                                    .font(.title2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .frame(width: 60, height: 60)
                                    .background(
                                        Circle()
                                            .fill(.thickMaterial)
                                            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                                    )
                            }
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
                case .checkIn(let episode, let checkInType):
                    CheckInView(episode: episode, checkInType: checkInType) {
                        activeSheet = nil
                        updateBadgeCount()
                    }
                }
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
            // Update badge count synchronously
            updateBadgeCount()

            // Check permissions in background
            Task.detached {
                await NotificationManager.shared.checkPermission()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Update badge count when app becomes active
            updateBadgeCount()
        }
    }
    
    private func updateBadgeCount() {
        // Count pending check-ins across all episodes
        let descriptor = FetchDescriptor<Episode>()

        do {
            let episodes = try modelContext.fetch(descriptor)
            var pendingCount = 0

            for episode in episodes {
                let completedCheckInTypes = Set(episode.checkIns.map { $0.checkInType })
                for checkInType in CheckInType.allCases {
                    if !completedCheckInTypes.contains(checkInType) &&
                       !episode.isCheckInDismissed(for: checkInType) &&
                       episode.isCheckInWindowActive(for: checkInType) {
                        pendingCount += 1
                    }
                }
            }

            DispatchQueue.main.async {
                // Clear delivered notifications from notification center
                UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                // Update badge to reflect actual pending count
                UNUserNotificationCenter.current().setBadgeCount(pendingCount)
                print("📱 Updated badge count to: \(pendingCount)")
            }
        } catch {
            print("❌ Error updating badge count: \(error)")
            UNUserNotificationCenter.current().setBadgeCount(0)
        }
    }
}

struct CardView: View {
    let card: Card
    
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
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel("Card image")
                        .accessibilityHint("Resilience card image for \(card.type.rawValue)")
                } else {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal)
                        .padding(.top)
                        .accessibilityLabel("Card image")
                        .accessibilityHint("Supporting image for this \(card.type.rawValue)")
                }
            }
            
            if !card.text.isEmpty {
                Text(card.text)
                    .font(.system(size: 32, weight: .regular, design: .default))
                    .padding(20)
                    .kerning(-0.3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(card.text)
            }
        }
        .background(card.color)
        .cornerRadius(20)
        .foregroundColor(card.color.contrastingTextColor())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to view actions. Swipe actions available.")
        .accessibilityAddTraits(.isButton)
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

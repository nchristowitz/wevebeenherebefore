import SwiftUI
import SwiftData

struct ResilienceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Card.createdAt, order: .reverse) private var cards: [Card]
    @Query private var episodes: [Episode]
    @ObservedObject private var notificationCoordinator = NotificationCoordinator.shared

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
    @State private var isShowingDebugView = false
    
    // Navigation state for deep linking
    @State private var selectedEpisode: Episode?
    @State private var checkInToShow: CheckInType?
    @State private var showingCheckIn = false
    
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
    
    var pendingCheckIns: [(episode: Episode, checkInType: CheckInType)] {
        var pending: [(Episode, CheckInType)] = []
        
        for episode in episodes {
            for checkInType in CheckInType.allCases {
                if episode.isCheckInWindowActive(for: checkInType) && 
                   !episode.hasCheckIn(for: checkInType) && 
                   !episode.isCheckInDismissed(for: checkInType) {
                    pending.append((episode, checkInType))
                }
            }
        }
        
        return pending.sorted { first, second in
            first.1.daysFromEpisode < second.1.daysFromEpisode
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main list content
                List {
                    // Check-in cards at the top
                    ForEach(pendingCheckIns.indices, id: \.self) { index in
                        let checkIn = pendingCheckIns[index]
                        CheckInCard(
                            episode: checkIn.episode,
                            checkInType: checkIn.checkInType,
                            onTap: {
                                selectedEpisode = checkIn.episode
                                checkInToShow = checkIn.checkInType
                                showingCheckIn = true
                            },
                            onDismiss: {
                                checkIn.episode.dismissCheckIn(for: checkIn.checkInType)
                                do {
                                    try modelContext.save()
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
                
                VStack {
                    Spacer()
                
                    // Bottom buttons
                    HStack(spacing: 24) {
                        CircularButton(
                            systemImage: "gearshape",
                            accessibilityLabel: "Settings",
                            accessibilityHint: "Open settings and filter menu"
                        ) {
                            isShowingFilterMenu = true
                        }
                        
                        ZStack {
                            CircularButton(
                                systemImage: "tornado",
                                accessibilityLabel: "Episodes",
                                accessibilityHint: "View and manage emotional episodes"
                            ) {
                                isShowingEpisodeMenu = true
                            }
                            
                            // Notification dot for pending check-ins
                            if hasPendingCheckIns {
                                NotificationDot()
                                    .offset(x: 22, y: -22)
                            }
                        }
                        
                        CircularButton(
                            systemImage: "plus",
                            accessibilityLabel: "Add Card",
                            accessibilityHint: "Add a new resilience card"
                        ) {
                            isShowingAddMenu = true
                        }
                        
                        // Debug button - only visible in debug builds
                        #if DEBUG
                        CircularButton(
                            systemImage: "hammer.fill",
                            accessibilityLabel: "Debug Tools",
                            accessibilityHint: "Open debug and testing tools"
                        ) {
                            isShowingDebugView = true
                        }
                        #endif
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                
                // Menu trays (always in view hierarchy)
                MenuTray(title: "Settings", isPresented: $isShowingFilterMenu) {
                    SettingsMenu(selectedFilter: $selectedFilter, isPresented: $isShowingFilterMenu)
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
            .sheet(isPresented: $showingCheckIn) {
                if let episode = selectedEpisode, let checkInType = checkInToShow {
                    CheckInView(episode: episode, checkInType: checkInType) {
                        // Called when check-in is completed
                        showingCheckIn = false
                        selectedEpisode = nil
                        checkInToShow = nil
                        updateBadgeCount()
                    }
                }
            }
            .sheet(isPresented: $isShowingDebugView) {
                DebugView()
            }
        }
        .onAppear {
            // Update badge count synchronously
            updateBadgeCount()
            
            // Navigate to pending check-in if a notification was tapped before the view appeared
            if let navigation = notificationCoordinator.pendingNavigation {
                handleNotificationNavigation(navigation)
                notificationCoordinator.clearPendingNavigation()
            }
            
            // Check permissions in background
            Task.detached {
                await NotificationManager.shared.checkPermission()
            }
        }
        .onChange(of: notificationCoordinator.pendingNavigation) { _, pendingNav in
            // Handle deep link navigation from notifications
            if let navigation = pendingNav {
                handleNotificationNavigation(navigation)
                notificationCoordinator.clearPendingNavigation()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Update badge count when app becomes active
            updateBadgeCount()
        }
    }
    
    private func handleNotificationNavigation(_ navigation: NotificationCoordinator.PendingNavigation) {
        print("🔍 Handling notification navigation for episode: \(navigation.episodeID), checkIn: \(navigation.checkInType.displayName)")
        
        // Find the episode by ID
        let descriptor = FetchDescriptor<Episode>()
        
        do {
            let episodes = try modelContext.fetch(descriptor)
            
            print("🔍 Looking for episode ID: '\(navigation.episodeID)'")
            print("🔍 Available episodes: \(episodes.count)")
            
            // Try to find episode by converting both IDs to strings for comparison
            var foundEpisode: Episode?
            for episode in episodes {
                let episodeIDString = "\(episode.persistentModelID)"
                print("  - Episode '\(episode.title)': '\(episodeIDString)'")
                if episodeIDString == navigation.episodeID {
                    foundEpisode = episode
                    break
                }
            }
            
            if let episode = foundEpisode {
                
                // Check if this check-in already exists
                let existingCheckIn = episode.checkIns.first { $0.checkInType == navigation.checkInType }
                
                if existingCheckIn == nil {
                    print("✅ Found episode '\(episode.title)', navigating to \(navigation.checkInType.displayName) check-in")
                    
                    // Navigate to check-in view
                    selectedEpisode = episode
                    checkInToShow = navigation.checkInType
                    
                    // Use a small delay to ensure UI is ready for sheet presentation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showingCheckIn = true
                    }
                } else {
                    print("ℹ️ Check-in already completed for \(navigation.checkInType.displayName)")
                    // Still clear the badge since user interacted with the notification
                    updateBadgeCount()
                }
            } else {
                print("❌ Episode not found for ID: \(navigation.episodeID)")
            }
        } catch {
            print("❌ Error fetching episodes: \(error)")
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
                    if !completedCheckInTypes.contains(checkInType) && episode.isCheckInWindowActive(for: checkInType) {
                        pendingCount += 1
                    }
                }
            }
            
            DispatchQueue.main.async {
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

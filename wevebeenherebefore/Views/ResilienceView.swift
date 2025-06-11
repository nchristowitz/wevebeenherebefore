import SwiftUI
import SwiftData

struct ResilienceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Card.createdAt, order: .reverse) private var cards: [Card]
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
    
    // Navigation state for deep linking
    @State private var selectedEpisode: Episode?
    @State private var checkInToShow: CheckInType?
    @State private var showingCheckIn = false
    
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
                        CircularButton(systemImage: "gearshape") {
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
        }
        .onAppear {
            // Update badge count synchronously
            updateBadgeCount()
            
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
        // Find the episode by ID
        let descriptor = FetchDescriptor<Episode>()
        
        do {
            let episodes = try modelContext.fetch(descriptor)
            if let episode = episodes.first(where: { "\($0.persistentModelID)" == navigation.episodeID }) {
                
                // Check if this check-in already exists
                let existingCheckIn = episode.checkIns.first { $0.checkInType == navigation.checkInType }
                
                if existingCheckIn == nil {
                    // Navigate to check-in view
                    selectedEpisode = episode
                    checkInToShow = navigation.checkInType
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showingCheckIn = true
                    }
                    
                    print("✅ Navigating to check-in: \(navigation.checkInType.displayName) for episode: \(episode.title)")
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

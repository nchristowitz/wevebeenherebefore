import SwiftUI
import SwiftData

struct EpisodeMenu: View {
    @Binding var isShowingEpisodeFlow: Bool
    @Binding var isShowingEpisodeList: Bool
    @Binding var isPresented: Bool
    @Query private var episodes: [Episode]

    private var hasPending: Bool {
        episodes.contains(where: { $0.hasPendingCheckIn })
    }
    
    var body: some View {
        VStack(spacing: 12) {
            MenuButton(
                title: "I'm having an episode",
                icon: "tornado",
                action: {
                    isPresented = false
                    isShowingEpisodeFlow = true
                }
            )
            
            MenuButton(
                title: "View my episodes",
                icon: "list.bullet",
                action: {
                    isPresented = false
                    isShowingEpisodeList = true
                }
            )
            .overlay(
                Group {
                    if hasPending {
                        NotificationDot()
                            .offset(x: 12, y: -12)
                    }
                }, alignment: .topTrailing
            )
        }
        .padding(.horizontal)
    }
} 

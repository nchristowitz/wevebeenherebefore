import SwiftUI

struct EpisodeMenu: View {
    @Binding var isShowingEpisodeFlow: Bool
    @Binding var isShowingEpisodeList: Bool
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    MenuButton(
                        title: "I'm having an episode",
                        icon: "heart.circle",
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
                }
                .padding()
            }
            .frame(idealHeight: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
} 
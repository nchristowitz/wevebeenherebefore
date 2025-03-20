import SwiftUI

struct EpisodeButton: View {
    @Binding var isShowingEpisodeFlow: Bool
    @Binding var isShowingEpisodeList: Bool
    
    var body: some View {
        Menu {
            Button(action: { isShowingEpisodeFlow = true }) {
                Label("I'm having an episode", systemImage: "heart.circle")
            }
            
            Button(action: { isShowingEpisodeList = true }) {
                Label("View my episodes", systemImage: "list.bullet")
            }
        } label: {
            CircularButton(systemImage: "light.beacon.max", action: {})
        }
    }
} 
import SwiftUI

struct EpisodeButton: View {
    @Binding var isShowingEpisodeFlow: Bool
    @Binding var isShowingEpisodeList: Bool
    
    var body: some View {
        Menu {
            Button(action: { isShowingEpisodeFlow = true }) {
                Label("I'm having an episode", systemImage: "tornado")
            }
            .accessibilityLabel("Start new episode")
            .accessibilityHint("Begin tracking a new emotional episode")
            
            Button(action: { isShowingEpisodeList = true }) {
                Label("View my episodes", systemImage: "list.bullet")
            }
            .accessibilityLabel("View episodes")
            .accessibilityHint("See all your previous emotional episodes")
        } label: {
            CircularButton(
                systemImage: "light.beacon.max",
                accessibilityLabel: "Episode Menu",
                accessibilityHint: "Open menu to start new episode or view previous episodes",
                action: {}
            )
        }
        .accessibilityLabel("Episode Menu")
        .accessibilityHint("Menu with options to start new episode or view previous episodes")
    }
} 
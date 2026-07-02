import Foundation
import MediaPlayer

// In-app playback of card songs via the application music player, so
// playing a delight doesn't disturb the Music app's own queue. Cards
// observe playingPersistentID to show play/pause state.
final class SongPlaybackManager: ObservableObject {
    static let shared = SongPlaybackManager()

    private let player = MPMusicPlayerController.applicationMusicPlayer

    @Published private(set) var playingPersistentID: String?

    private init() {
        player.beginGeneratingPlaybackNotifications()

        NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: player,
            queue: .main
        ) { [weak self] _ in
            self?.syncFromPlayer()
        }
    }

    func isPlaying(_ song: CardSong) -> Bool {
        playingPersistentID == song.persistentID
    }

    func toggle(_ song: CardSong) {
        if isPlaying(song) {
            player.pause()
            playingPersistentID = nil
        } else {
            play(song)
        }
    }

    private func play(_ song: CardSong) {
        // Prefer the item in the device library; fall back to the
        // catalog store ID (e.g. after restoring a backup on a new phone)
        if let id = UInt64(song.persistentID) {
            let query = MPMediaQuery(filterPredicates: [
                MPMediaPropertyPredicate(
                    value: NSNumber(value: id),
                    forProperty: MPMediaItemPropertyPersistentID
                )
            ])
            if let items = query.items, !items.isEmpty {
                player.setQueue(with: MPMediaItemCollection(items: items))
                player.play()
                playingPersistentID = song.persistentID
                return
            }
        }

        if let storeID = song.storeID {
            player.setQueue(with: [storeID])
            player.play()
            playingPersistentID = song.persistentID
        }
    }

    // Keep the published state honest when playback ends on its own,
    // gets interrupted, or is paused/resumed from Control Center
    private func syncFromPlayer() {
        switch player.playbackState {
        case .playing:
            // Resume from outside the app: recover the id from the player.
            // Streaming items can report persistentID 0, so never overwrite
            // an id we set ourselves when starting playback.
            if playingPersistentID == nil,
               let item = player.nowPlayingItem, item.persistentID != 0 {
                playingPersistentID = String(item.persistentID)
            }
        case .interrupted:
            break // transient (phone call etc.) — keep the current state
        default:
            playingPersistentID = nil
        }
    }
}

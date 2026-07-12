import SwiftUI
import MediaPlayer

extension CardSong {
    init(mediaItem: MPMediaItem) {
        self.init(
            persistentID: String(mediaItem.persistentID),
            storeID: mediaItem.playbackStoreID.isEmpty || mediaItem.playbackStoreID == "0"
                ? nil : mediaItem.playbackStoreID,
            title: mediaItem.title ?? "Unknown Song",
            artist: mediaItem.artist ?? "",
            artworkData: mediaItem.artwork?
                .image(at: CGSize(width: 120, height: 120))?
                .jpegData(compressionQuality: 0.8)
        )
    }
}

// The system Apple Music library picker.
struct SongPicker: UIViewControllerRepresentable {
    let onPick: (CardSong) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MPMediaPickerController {
        let picker = MPMediaPickerController(mediaTypes: .music)
        picker.allowsPickingMultipleItems = false
        picker.showsCloudItems = true
        picker.prompt = "Choose a song"
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: MPMediaPickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, MPMediaPickerControllerDelegate {
        let parent: SongPicker

        init(_ parent: SongPicker) {
            self.parent = parent
        }

        func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
            if let item = mediaItemCollection.items.first {
                parent.onPick(CardSong(mediaItem: item))
            }
            parent.dismiss()
        }

        func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
            parent.dismiss()
        }
    }
}

// Accessory chip for the card editors: checks media library access,
// then flips the binding that presents the song picker sheet.
struct AddSongChip: View {
    let textColor: Color
    @Binding var isShowingPicker: Bool
    @Binding var isShowingAccessAlert: Bool

    var body: some View {
        GlassAccessoryChip {
            Button(action: presentPicker) {
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                    Text("Add Song")
                }
                .foregroundColor(textColor)
            }
        }
    }

    private func presentPicker() {
        switch MPMediaLibrary.authorizationStatus() {
        case .authorized:
            isShowingPicker = true
        case .notDetermined:
            MPMediaLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    if status == .authorized {
                        isShowingPicker = true
                    } else {
                        isShowingAccessAlert = true
                    }
                }
            }
        default:
            isShowingAccessAlert = true
        }
    }
}

// Song attachment shown on cards and in the editors — artwork,
// title/artist and play/pause, in the spirit of an iMessage song
// preview. Two styles: .row is the full-width attachment row used in
// editors and on image-less cards; .floating is a content-hugging
// capsule overlaid bottom-center on card imagery, where the whole
// pill is the play/pause target.
struct CardSongRow: View {
    enum Style {
        case row
        case floating
    }

    let song: CardSong
    var style: Style = .row
    var onRemove: (() -> Void)? = nil

    @ObservedObject private var playback = SongPlaybackManager.shared

    private var isPlaying: Bool {
        playback.isPlaying(song)
    }

    var body: some View {
        switch style {
        case .row:
            rowBody
        case .floating:
            floatingBody
        }
    }

    private var floatingBody: some View {
        Button {
            playback.toggle(song)
        } label: {
            HStack(spacing: 10) {
                artwork
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 1) {
                    Text(song.title)
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    if !song.artist.isEmpty {
                        Text(song.artist)
                            .font(.caption2)
                            .opacity(0.7)
                            .lineLimit(1)
                    }
                }

                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.leading, 2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundColor(.primary)
            .background(.regularMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaying ? "Pause \(song.title)" : "Play \(song.title)")
    }

    private var rowBody: some View {
        HStack(spacing: 12) {
            artwork
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                if !song.artist.isEmpty {
                    Text(song.artist)
                        .font(.caption)
                        .opacity(0.7)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Button {
                playback.toggle(song)
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32))
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Pause \(song.title)" : "Play \(song.title)")

            if let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove song")
            }
        }
        .padding(10)
        .foregroundColor(.primary)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var artwork: some View {
        if let artworkData = song.artworkData,
           let uiImage = UIImage(data: artworkData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                Image(systemName: "music.note")
                    .font(.title3)
                    .opacity(0.6)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        CardSongRow(song: CardSong(
            persistentID: "1",
            storeID: nil,
            title: "Here Comes the Sun",
            artist: "The Beatles",
            artworkData: nil
        ))

        CardSongRow(
            song: CardSong(
                persistentID: "2",
                storeID: nil,
                title: "Weightless",
                artist: "Marconi Union",
                artworkData: nil
            ),
            onRemove: {}
        )

        CardSongRow(
            song: CardSong(
                persistentID: "3",
                storeID: nil,
                title: "Here Comes the Sun",
                artist: "The Beatles",
                artworkData: nil
            ),
            style: .floating
        )
    }
    .padding(20)
    .background(Color.orange)
}

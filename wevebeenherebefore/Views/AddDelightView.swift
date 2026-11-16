import SwiftUI
import PhotosUI
import MediaPlayer

struct AddDelightView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var selectedColor: Color
    @Environment(\.colorScheme) private var colorScheme
    @State private var attachedSong: CardSong?
    @State private var isShowingSongPicker = false
    @State private var isShowingMusicAccessAlert = false
    let existingCard: Card?

    init(existingCard: Card? = nil) {
        self.existingCard = existingCard
        _selectedColor = State(initialValue: existingCard?.color ?? Card.defaultColor)
        _selectedImageData = State(initialValue: existingCard?.imageData)
        _attachedSong = State(initialValue: existingCard?.song)
    }

    var body: some View {
        AddCardBaseView(
            type: .delight,
            selectedColor: $selectedColor,
            imageData: selectedImageData,
            song: attachedSong,
            onRemoveImage: {
                selectedImageData = nil
                selectedItem = nil
            },
            existingCard: existingCard
        ) {
            VStack(spacing: 12) {
                if let song = attachedSong {
                    CardSongRow(song: song, onRemove: {
                        attachedSong = nil
                    })
                }

                HStack {
                    GlassAccessoryChip {
                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            HStack(spacing: 6) {
                                Image(systemName: "photo")
                                Text("Add Photo")
                            }
                            .foregroundColor(selectedColor.cardTextColor(for: colorScheme))
                        }
                        .onChange(of: selectedItem) {
                            Task {
                                if let original = try? await selectedItem?.loadTransferable(type: Data.self) {
                                    // Store a screen-sized copy, not the full-resolution original
                                    let data = Card.downscaledImageData(original) ?? original
                                    selectedImageData = data
                                    if let uiImage = UIImage(data: data),
                                       let color = await extractColor(from: uiImage) {
                                        selectedColor = color
                                    }
                                }
                            }
                        }
                    }

                    if attachedSong == nil {
                        AddSongChip(
                            textColor: selectedColor.cardTextColor(for: colorScheme),
                            isShowingPicker: $isShowingSongPicker,
                            isShowingAccessAlert: $isShowingMusicAccessAlert
                        )
                    }

                    Spacer()

                    GlassColorChip(selection: $selectedColor)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $isShowingSongPicker) {
            SongPicker { song in
                attachedSong = song
            }
        }
        .alert("No Access to Apple Music", isPresented: $isShowingMusicAccessAlert) {
            Button("OK") { }
        } message: {
            Text("Allow access to your media library in Settings to attach songs.")
        }
    }
    
    
    private func extractColor(from image: UIImage) async -> Color? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let color = image.averageColor.map { Color(uiColor: $0) } ?? Card.defaultColor
                continuation.resume(returning: color)
            }
        }
    }
}

// Helper extension to get average color from UIImage
extension UIImage {
    var averageColor: UIColor? {
        guard let inputImage = CIImage(image: self) else { return nil }
        let extentVector = CIVector(x: inputImage.extent.origin.x,
                                  y: inputImage.extent.origin.y,
                                  z: inputImage.extent.size.width,
                                  w: inputImage.extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage",
                                  parameters: [kCIInputImageKey: inputImage,
                                             kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(outputImage,
                      toBitmap: &bitmap,
                      rowBytes: 4,
                      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                      format: .RGBA8,
                      colorSpace: nil)

        return UIColor(red: CGFloat(bitmap[0]) / 255,
                      green: CGFloat(bitmap[1]) / 255,
                      blue: CGFloat(bitmap[2]) / 255,
                      alpha: CGFloat(bitmap[3]) / 255)
    }
}

#Preview {
    AddDelightView()
} 
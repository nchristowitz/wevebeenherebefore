import SwiftUI
import PhotosUI

struct AddDelightView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var selectedColor: Color
    let existingCard: Card?
    
    init(existingCard: Card? = nil) {
        self.existingCard = existingCard
        _selectedColor = State(initialValue: existingCard?.color ?? Color(uiColor: .systemGray6))
        _selectedImageData = State(initialValue: existingCard?.imageData)
    }
    
    var body: some View {
        AddCardBaseView(
            type: .delight,
            selectedColor: $selectedColor,
            imageData: selectedImageData,
            existingCard: existingCard
        ) {
            HStack {
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack {
                        Image(systemName: "photo")
                        Text("Add Photo")
                    }
                    .foregroundColor(selectedColor.contrastingTextColor())
                }
                .onChange(of: selectedItem) {
                    Task {
                        if let data = try? await selectedItem?.loadTransferable(type: Data.self) {
                            selectedImageData = data
                            if let uiImage = UIImage(data: data),
                               let color = await extractColor(from: uiImage) {
                                selectedColor = color
                            }
                        }
                    }
                }
                
                Spacer()
                
                ColorPicker("", selection: $selectedColor)
                    .labelsHidden()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
    }
    
    
    private func extractColor(from image: UIImage) async -> Color? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let uiColor = image.averageColor ?? .systemGray6
                continuation.resume(returning: Color(uiColor: uiColor))
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
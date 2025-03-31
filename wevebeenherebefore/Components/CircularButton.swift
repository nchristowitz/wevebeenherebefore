import SwiftUI

struct CircularButton: View {
    let systemImage: String
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(.thickMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                )
                .animation(.spring(response: 0.3), value: isPressed)
        }
        .pressEvents(onPress: { isPressed = true }, onRelease: { isPressed = false })
    }
}

// Helper extension for press events
extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
} 

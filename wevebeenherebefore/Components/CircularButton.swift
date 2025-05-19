import SwiftUI

struct CircularButton: View {
    let systemImage: String
    let action: () -> Void
    
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
        }
    }
}

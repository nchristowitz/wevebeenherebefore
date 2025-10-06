import SwiftUI

struct CircularButton: View {
    let systemImage: String
    let action: () -> Void
    let accessibilityLabel: String
    let accessibilityHint: String?

    init(systemImage: String, accessibilityLabel: String, accessibilityHint: String? = nil, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.action = action
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .fontWeight(.medium)
                    .frame(width: 60, height: 60)
            }
            .tint(.primary)
            .glassEffect()
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(accessibilityHint ?? "")
        } else {
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
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(accessibilityHint ?? "")
            .accessibilityAddTraits(.isButton)
        }
    }
}

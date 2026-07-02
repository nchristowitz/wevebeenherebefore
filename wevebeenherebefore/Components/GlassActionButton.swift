import SwiftUI

// Full-width primary action button used across the episode flow
// (emotion rating, prompts, check-in verdict, remember carousels).
// Liquid glass on iOS 26, thick material capsule on earlier versions.
struct GlassActionButton: View {
    let title: String
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            if #available(iOS 26.0, *) {
                label
                    .glassEffect()
            } else {
                label
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.thickMaterial)
                    )
            }
        }
        .opacity(isEnabled ? 1 : 0.4)
        .animation(.easeInOut(duration: 0.15), value: isEnabled)
    }

    private var label: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding()
    }
}

#Preview {
    VStack(spacing: 20) {
        GlassActionButton(title: "Next") {}

        GlassActionButton(title: "Done") {}
            .disabled(true)
    }
    .padding()
}

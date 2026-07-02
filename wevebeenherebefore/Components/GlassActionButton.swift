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

// Floating glass chip for the input accessories on the card editors
// (photo picker, date picker, color well). Same iOS 26 / fallback split
// as GlassActionButton, sized for compact controls.
struct GlassAccessoryChip<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            padded
                .glassEffect()
        } else {
            padded
                .background(Capsule().fill(.thickMaterial))
        }
    }

    private var padded: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
    }
}

#Preview {
    VStack(spacing: 20) {
        GlassActionButton(title: "Next") {}

        GlassActionButton(title: "Done") {}
            .disabled(true)

        HStack {
            GlassAccessoryChip {
                Label("Add Photo", systemImage: "photo")
            }

            Spacer()

            GlassAccessoryChip {
                ColorPicker("", selection: .constant(.orange))
                    .labelsHidden()
            }
        }
    }
    .padding()
    .background(Color(uiColor: .systemGray6))
}

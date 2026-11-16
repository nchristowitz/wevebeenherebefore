import SwiftUI

struct EmotionRatingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var emotions: [String: Int] = [
        "Anger": 0,
        "Sadness": 0,
        "Fear": 0,
        "Anxiety": 0,
        "Shame": 0,
        "Disgust": 0,
        "Grief": 0,
        "Confusion": 0
    ]
    
    let onComplete: ([String: Int]) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    Text("What are you feeling right now?")
                        .font(.title)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top)
                        .accessibilityAddTraits(.isHeader)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(Array(emotions.keys.sorted()), id: \.self) { emotion in
                            EmotionRatingRow(
                                emotion: emotion,
                                rating: Binding(
                                    get: { emotions[emotion] ?? 0 },
                                    set: { emotions[emotion] = $0 }
                                )
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Emotion ratings")
                }
                .padding(.horizontal)
            }
            .accessibilityLabel("Emotion rating form")
            
            GlassActionButton(title: "Next") {
                onComplete(emotions)
            }
            .padding()
            .accessibilityHint("Continue to next step with current emotion ratings")
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    dismiss()
                }
            }
        }
    }
}

struct EmotionRatingRow: View {
    let emotion: String
    @Binding var rating: Int

    private var color: Color {
        EmotionColor.color(for: emotion)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(emotion)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            // Five short segments rather than full circles, so more rows fit
            // on screen. Segments up to the rating fill with the emotion's color.
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { value in
                    let isFilled = rating >= value

                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isFilled ? color : Color.primary.opacity(0.08))
                        .frame(height: 44)
                        .overlay(
                            Text("\(value)")
                                .font(.subheadline)
                                .fontWeight(isFilled ? .semibold : .regular)
                                .foregroundColor(isFilled ? .white : .primary)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                // Tapping the current rating again clears it
                                rating = rating == value ? 0 : value
                            }
                        }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

// One hue per emotion, shared by the rating rows and the episode detail
// bars. Emotions outside the rating list (from older episodes) are gray.
enum EmotionColor {
    static func color(for emotion: String) -> Color {
        switch emotion {
        case "Anger":
            return .red
        case "Sadness":
            return .blue
        case "Fear":
            return .purple
        case "Anxiety":
            return .indigo
        case "Shame":
            return .brown
        case "Disgust":
            return .green
        case "Grief":
            return .teal
        case "Confusion":
            return .orange
        default:
            return .gray
        }
    }
}


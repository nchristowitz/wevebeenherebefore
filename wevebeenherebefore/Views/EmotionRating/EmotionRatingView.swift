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
                    
                    VStack(alignment: .leading, spacing: 24) {
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
                }
                .padding(.horizontal)
            }
            
            Button(action: {
                onComplete(emotions)
            }) {
                Text("Next")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(12)
            }
            .padding()
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(emotion)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            GeometryReader { geometry in
                let availableWidth = geometry.size.width
                let spacing: CGFloat = 16
                let totalSpacing = spacing * 4 // 4 spaces between 5 circles
                let circleSize = (availableWidth - totalSpacing) / 5
                
                HStack(spacing: spacing) {
                    ForEach(1...5, id: \.self) { value in
                        Circle()
                            .fill(rating >= value ? Color.black : Color.black.opacity(0.1))
                            .overlay(
                                Text("\(value)")
                                    .foregroundColor(rating >= value ? .white : .black)
                            )
                            .frame(width: circleSize, height: circleSize)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    rating = value
                                }
                            }
                    }
                }
            }
            .frame(height: max(44, (UIScreen.main.bounds.width - 96) / 5)) // Ensure minimum height of 44pt
        }
    }
}

#Preview {
    NavigationStack {
        EmotionRatingView { emotions in
            print(emotions)
        }
    }
} 

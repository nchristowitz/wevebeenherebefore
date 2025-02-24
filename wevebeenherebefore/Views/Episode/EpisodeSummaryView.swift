import SwiftUI

struct EpisodeSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    let emotions: [String: Int]
    let prompts: [String: String]
    let title: String
    let onSave: () -> Void
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()
    
    private func fontSizeForRating(_ rating: Int) -> CGFloat {
        let baseFontSize: CGFloat = 14
        let scaleFactor: CGFloat = 1.5
        return baseFontSize * pow(scaleFactor, CGFloat(rating - 1))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Date and Title
                VStack(alignment: .leading, spacing: 8) {
                    Text(dateFormatter.string(from: Date()))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(title)
                        .font(.title)
                        .fontWeight(.bold)
                }
                
                // Emotions
                VStack(alignment: .leading, spacing: 16) {
                    Text("Emotions")
                        .font(.headline)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(Array(emotions.sorted(by: { $0.value > $1.value })), id: \.key) { emotion, rating in
                            if rating > 0 {
                                Text(emotion)
                                    .font(.system(size: fontSizeForRating(rating)))
                                    .fontWeight(.medium)
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.black.opacity(0.05))
                                    )
                            }
                        }
                    }
                }
                
                // Prompts and Responses
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(Array(prompts.sorted(by: { $0.key < $1.key })), id: \.key) { prompt, response in
                        if prompt != "Let's give this episode a title" {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(prompt)
                                    .font(.headline)
                                
                                Text(response)
                                    .font(.body)
                            }
                        }
                    }
                }
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
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    onSave()
                }
                .fontWeight(.medium)
            }
        }
    }
}

// Helper view for flowing emotion tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        return arrangeSubviews(sizes: sizes, proposal: proposal).size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let offsets = arrangeSubviews(sizes: sizes, proposal: proposal).offsets
        
        for (offset, subview) in zip(offsets, subviews) {
            subview.place(at: bounds.origin + offset, proposal: .unspecified)
        }
    }
    
    private func arrangeSubviews(sizes: [CGSize], proposal: ProposedViewSize) -> (offsets: [CGPoint], size: CGSize) {
        let width = proposal.width ?? .infinity
        var offsets: [CGPoint] = []
        var currentPosition = CGPoint.zero
        var maxY: CGFloat = 0
        
        for size in sizes {
            if currentPosition.x + size.width > width && currentPosition.x > 0 {
                currentPosition.x = 0
                currentPosition.y = maxY + spacing
            }
            
            offsets.append(currentPosition)
            currentPosition.x += size.width + spacing
            maxY = max(maxY, currentPosition.y + size.height)
        }
        
        return (offsets, CGSize(width: width, height: maxY))
    }
}

// Replace the operator overload with an extension
extension CGPoint {
    static func + (left: CGPoint, right: CGPoint) -> CGPoint {
        return CGPoint(x: left.x + right.x, y: left.y + right.y)
    }
}

#Preview {
    NavigationStack {
        EpisodeSummaryView(
            emotions: [
                "Anger": 5,
                "Sadness": 3,
                "Fear": 2,
                "Anxiety": 4
            ],
            prompts: [
                "Describe the episode": "I felt overwhelmed at work when...",
                "What triggered it?": "A deadline was moved up unexpectedly",
                "What do you need right now?": "Some time to breathe and reorganize",
                "Let's give this episode a title": "Unexpected deadline change"
            ],
            title: "Unexpected deadline change",
            onSave: {}
        )
    }
} 
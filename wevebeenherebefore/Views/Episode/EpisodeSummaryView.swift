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
    
    private func colorForEmotion(_ emotion: String) -> Color {
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
    
    // Define the order of prompts
        private let promptOrder = [
            "Describe the episode",
            "How do you think you'll feel tomorrow?",
            "How do you think you'll feel about this in 2 weeks?",
            "What's the worst that can happen?",
            "How about in 3 months?"
            // The title is handled separately and not shown in the prompts section
        ]
    
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
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    FlowLayout(spacing: 12) {
                        ForEach(Array(emotions.sorted(by: { $0.value > $1.value })), id: \.key) { emotion, rating in
                            if rating > 0 {
                                Text(emotion)
                                    .font(.system(size: fontSizeForRating(rating)))
                                    .fontWeight(.semibold)
                                    .foregroundColor(colorForEmotion(emotion))
                            }
                        }
                    }
                }
                
                // Prompts and Responses in desired order
                VStack(alignment: .leading, spacing: 24) {
                    // First, show prompts in the defined order (if they exist)
                    ForEach(promptOrder, id: \.self) { promptKey in
                        if let response = prompts[promptKey] {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(promptKey)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                
                                Text(response)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Then show any remaining prompts (except the title prompt)
                    ForEach(Array(prompts.keys.sorted()).filter { key in
                        key != "Let's give this episode a title" && !promptOrder.contains(key)
                    }, id: \.self) { promptKey in
                        if let response = prompts[promptKey] {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(promptKey)
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

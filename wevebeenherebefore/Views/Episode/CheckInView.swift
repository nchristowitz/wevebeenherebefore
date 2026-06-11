import SwiftUI
import SwiftData

struct CheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    let episode: Episode
    let checkInType: CheckInType
    let existingCheckIn: CheckIn?
    let onCompletion: (() -> Void)?
    
    @State private var checkInText: String = ""
    @State private var isOriginalResponseExpanded: Bool = false
    @State private var verdictPair: PredictionRealityPair?

    init(episode: Episode, checkInType: CheckInType, existingCheckIn: CheckIn? = nil, onCompletion: (() -> Void)? = nil) {
        self.episode = episode
        self.checkInType = checkInType
        self.existingCheckIn = existingCheckIn
        self.onCompletion = onCompletion
        _checkInText = State(initialValue: existingCheckIn?.text ?? "")
    }

    var body: some View {
        NavigationView {
            if let pair = verdictPair {
                verdictView(for: pair)
            } else {
                editorView
            }
        }
        .onAppear {
            isFocused = true
        }
    }

    // The "we've been here before" proof moment shown right after saving:
    // what you predicted at episode time next to what you just wrote
    private func verdictView(for pair: PredictionRealityPair) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("We've been here before")
                    .font(.title)
                    .fontWeight(.bold)

                Text("What you feared then, and what you know now.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
            .padding(.bottom, 8)

            PredictionRealityCard(pair: pair)
                .padding(.vertical, 8)

            continueButton
                .padding(.top, 8)
                .padding(.bottom, 20)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var continueButton: some View {
        if #available(iOS 26.0, *) {
            Button(action: finishVerdict) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .glassEffect()
            }
        } else {
            Button(action: finishVerdict) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.thickMaterial)
                    )
            }
        }
    }

    private func finishVerdict() {
        onCompletion?()
        dismiss()
    }

    private var editorView: some View {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isEditing ? "Edit \(checkInType.displayName.lowercased())" : "Add \(checkInType.displayName.lowercased())")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.leading, 5)
                        .padding(.top)
                }
                
              
                
                TextEditor(text: $checkInText)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .background(.clear)
                    .font(.system(size: 24, weight: .regular, design: .default))
                    .overlay(
                        Group {
                            if checkInText.isEmpty {
                                Text(placeholderText)
                                    .font(.system(size: 24, weight: .regular, design: .default))
                                    .foregroundColor(.primary.opacity(0.5))
                                    .allowsHitTesting(false)
                                    .padding(.leading, 5)
                                    .padding(.top, 8)
                            }
                        },
                        alignment: .topLeading
                    )
                
                // Show original response if available
                if let originalResponse = episode.prediction(for: checkInType) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your original response:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isOriginalResponseExpanded.toggle()
                            }
                        }) {
                            Text(originalResponse)
                                .font(.caption)
                                .fontWeight(.regular)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                                .lineLimit(isOriginalResponseExpanded ? nil : 3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCompletion?()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCheckIn()
                    }
                    .disabled(checkInText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
    }

    private var isEditing: Bool {
        existingCheckIn != nil
    }
    
    private var placeholderText: String {
        switch checkInType {
        case .twentyFourHour:
            return "How are you feeling compared to yesterday?"
        case .twoWeek:
            return "Looking back at this episode after 2 weeks, how do you feel about it now?"
        case .threeMonth:
            return "After 3 months, what's your perspective on this episode? Has it affected you as much as you thought it would?"
        }
    }
    private func saveCheckIn() {
        let trimmedText = checkInText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        do {
            if let existingCheckIn = existingCheckIn {
                existingCheckIn.text = trimmedText
            } else {
                let checkIn = CheckIn(text: trimmedText, checkInType: checkInType, episode: episode)
                modelContext.insert(checkIn)

                // Cancel the notification for this check-in type
                episode.cancelNotificationForCheckIn(checkInType)
            }

            // Save the context to persist changes
            try modelContext.save()

            // Recalculate the badge from actual pending check-ins rather than
            // zeroing it, in case other episodes still have one pending
            NotificationManager.shared.refreshBadgeCount(modelContext: modelContext)

            // For a fresh check-in with a prediction on record, show the
            // proof moment before closing; otherwise close straight away
            if existingCheckIn == nil, let prediction = episode.prediction(for: checkInType) {
                isFocused = false
                withAnimation(.easeInOut(duration: 0.3)) {
                    verdictPair = PredictionRealityPair(
                        episode: episode,
                        checkInType: checkInType,
                        prediction: prediction,
                        reality: trimmedText,
                        realityDate: Date()
                    )
                }
            } else {
                onCompletion?()
                dismiss()
            }

        } catch {
            // Handle the error gracefully
            print("Error saving check-in: \(error)")
            // Could show an alert to the user here, but for now just continue
            onCompletion?()
            dismiss()
        }
    }
}

#Preview {
    let episode = Episode(
        title: "Work Stress Episode",
        emotions: ["Anxiety": 4, "Overwhelm": 3],
        prompts: [
            "Describe the episode": "I felt completely overwhelmed when my manager gave me three urgent projects with conflicting deadlines. My heart was racing and I couldn't focus on any single task.",
            "How do you think you'll feel tomorrow?": "I'm worried I'll still be anxious about not finishing everything perfectly. The pressure will probably feel even worse after sleeping on it.",
            "How do you think you'll feel about this in 2 weeks?": "Maybe I'll have figured out a better system for handling multiple priorities. Hopefully the deadlines won't feel as scary.",
            "What's the worst that can happen?": "I could miss all the deadlines, disappoint my team, and potentially lose my job. Everyone would see me as incompetent.",
            "How will you feel 3 months from now?": "This will probably just be another stressful work memory. I'll have dealt with other challenges by then and this won't seem as big."
        ]
    )
    
    return Group {
        // 24-hour check-in preview
        CheckInView(episode: episode, checkInType: .twentyFourHour)
            .previewDisplayName("24-Hour Check-in")

    }
    .modelContainer(for: [Episode.self, CheckIn.self], inMemory: true)
}

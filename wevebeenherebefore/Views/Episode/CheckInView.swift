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
    @State private var isPredictionUnsealed: Bool = false
    @State private var verdictPair: PredictionRealityPair?
    @State private var saveError: String?

    init(episode: Episode, checkInType: CheckInType, existingCheckIn: CheckIn? = nil, onCompletion: (() -> Void)? = nil) {
        self.episode = episode
        self.checkInType = checkInType
        self.existingCheckIn = existingCheckIn
        self.onCompletion = onCompletion
        _checkInText = State(initialValue: existingCheckIn?.text ?? "")
    }

    var body: some View {
        NavigationStack {
            if let pair = verdictPair {
                verdictView(for: pair)
            } else {
                editorView
            }
        }
        .onAppear {
            isFocused = true
        }
        .saveErrorAlert($saveError)
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
            .padding(.top, 40)
            .padding(.bottom, 8)

            // Skip the reveal animation if the user already peeked
            PredictionRealityCard(pair: pair, revealsPrediction: !isPredictionUnsealed)
                .padding(.vertical, 8)

            continueButton
                .padding(.top, 8)
                .padding(.bottom, 20)
        }
        .padding(.horizontal)
    }

    private var continueButton: some View {
        GlassActionButton(title: "Continue", action: finishVerdict)
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

                if let prediction = episode.prediction(for: checkInType) {
                    predictionView(prediction)
                        .padding(.top, 12)
                        .padding(.bottom, 4)
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

    // The prediction made at episode time. For a new check-in it starts
    // sealed — blurred and unreadable — so how the user feels now isn't
    // anchored to what they expected; saving reveals it on the verdict
    // screen. Tapping unseals it early. When editing, it has already been
    // revealed, so it shows plainly. Once readable, tapping expands it.
    private func predictionView(_ prediction: String) -> some View {
        let isSealed = !isEditing && !isPredictionUnsealed

        return VStack(alignment: .leading, spacing: 8) {
            Text("Your prediction")
                .font(.caption)
                .fontWeight(.semibold)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            Button {
                if isSealed {
                    withAnimation(.easeOut(duration: 0.6)) {
                        isPredictionUnsealed = true
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isOriginalResponseExpanded.toggle()
                    }
                }
            } label: {
                Text(prediction)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .lineLimit(isOriginalResponseExpanded ? nil : 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .blur(radius: isSealed ? PredictionRealityCard.sealedBlurRadius : 0)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSealed ? "Prediction, hidden" : prediction)
            .accessibilityHint(isSealed ? "Double tap to reveal" : "")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
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
            }

            // Save the context to persist changes
            try modelContext.save()

            // Only once the check-in is safely stored: its reminder is no
            // longer needed (the ID change is picked up by autosave)
            if existingCheckIn == nil {
                episode.cancelNotificationForCheckIn(checkInType)
            }

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
            // Undo the unsaved insert/edit so a retry doesn't double up, and
            // keep the sheet open with the text intact
            print("Error saving check-in: \(error)")
            modelContext.rollback()
            saveError = saveErrorMessage(for: error)
        }
    }
}

#Preview("24-Hour Check-in") {
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
    
    return CheckInView(episode: episode, checkInType: .twentyFourHour)
        .modelContainer(for: [Episode.self, CheckIn.self], inMemory: true)
}

import SwiftUI

struct EpisodePromptView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    let prompt: EpisodePrompt
    @Binding var text: String
    let onNext: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(prompt.question)
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.leading, 5)

            }
            
            TextEditor(text: $text)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .background(.clear)
                .font(.system(size: 24, weight: .regular, design: .default))
                .overlay(
                    Group {
                        if text.isEmpty {
                            Text(prompt.placeholder)
                                .font(.system(size: 24, weight: .regular, design: .default))
                                .foregroundColor(.primary.opacity(0.5))
                                .allowsHitTesting(false)
                                .padding(.leading, 5)
                                .padding(.top, 8)
                        }
                    },
                    alignment: .topLeading
                )

            GlassActionButton(title: prompt.isLast ? "Done" : "Next", action: onNext)
                .disabled(text.isEmpty)
                .padding(.top, 8)
                .accessibilityHint("Continue to the next prompt")
        }
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
        .navigationBarBackButtonHidden(false)
        .onAppear {
            isFocused = true
        }
    }
}

// The single source of truth for the episode prompts. Answers are stored
// in Episode.prompts keyed by the question's wording at the time, so a
// reworded question keeps its old wordings in `earlierQuestions` — that's
// how old episodes still find their predictions and display in order.
struct EpisodePrompt: Identifiable, Equatable {
    let id: Int
    let question: String
    let placeholder: String
    var isLast: Bool
    // The check-in whose answer this prompt predicts, if any
    var checkInType: CheckInType? = nil
    // Earlier wordings of this question, still used as keys by old episodes
    var earlierQuestions: [String] = []

    // Every wording this prompt's answer may be stored under, current first
    var allQuestions: [String] {
        [question] + earlierQuestions
    }

    static func == (lhs: EpisodePrompt, rhs: EpisodePrompt) -> Bool {
        lhs.id == rhs.id
    }

    static let titleQuestion = "Let's give this episode a title"

    static let prompts: [EpisodePrompt] = [
            EpisodePrompt(
                id: 0,
                question: "Describe the episode",
                placeholder: "Think about future you as you write this, keep it short but detailed enough",
                isLast: false
            ),
            EpisodePrompt(
                id: 1,
                question: "How do you think you'll feel tomorrow?",
                placeholder: "Sometimes the immediate future feels scarier than it actually is",
                isLast: false,
                checkInType: .twentyFourHour
            ),
            EpisodePrompt(
                id: 2,
                question: "How do you think you'll feel about this in 2 weeks?",
                placeholder: "Try to imagine yourself looking back at this moment",
                isLast: false,
                checkInType: .twoWeek,
                earlierQuestions: ["How do you think you'll feel two weeks from now?"]
            ),
            EpisodePrompt(
                id: 3,
                question: "What's the worst that can happen?",
                placeholder: "What's the nuclear option? Play it out in your mind.",
                isLast: false
            ),
            EpisodePrompt(
                id: 4,
                question: "What would Christina say?",
                placeholder: "Imagine she's here with you now, guiding you through this.",
                isLast: false
            ),
            EpisodePrompt(
                id: 5,
                question: "How will you feel 3 months from now?",
                placeholder: "Think about the bigger picture",
                isLast: false,
                checkInType: .threeMonth,
                earlierQuestions: [
                    "How about in 3 months?",
                    "What about 3 months from now?",
                    "How do you think you'll feel about this in 3 months?"
                ]
            ),
            EpisodePrompt(
                id: 6,
                question: titleQuestion,
                placeholder: "Keep it short but recognizable to future you",
                isLast: true
            )
        ]

    // An episode's answers in prompt order, ready to display. Each answer
    // keeps the wording it was actually given under. Answers to questions
    // no longer asked come last, alphabetically. The title is left out —
    // it's shown separately.
    static func answeredPrompts(from responses: [String: String]) -> [AnsweredPrompt] {
        var remaining = responses
        remaining.removeValue(forKey: titleQuestion)

        var result: [AnsweredPrompt] = []

        for prompt in prompts where !prompt.isLast {
            var hasAttachedCheckIn = false
            for question in prompt.allQuestions {
                guard let response = remaining.removeValue(forKey: question) else { continue }
                // Only the first matching wording carries the check-in, so
                // it can never show twice
                result.append(AnsweredPrompt(
                    question: question,
                    response: response,
                    checkInType: hasAttachedCheckIn ? nil : prompt.checkInType
                ))
                hasAttachedCheckIn = true
            }
        }

        result += remaining
            .sorted { $0.key < $1.key }
            .map { AnsweredPrompt(question: $0.key, response: $0.value, checkInType: nil) }

        return result
    }
}

struct AnsweredPrompt: Identifiable {
    let question: String
    let response: String
    let checkInType: CheckInType?

    var id: String { question }
}

#Preview {
    NavigationStack {
        EpisodePromptView(
            prompt: EpisodePrompt.prompts[0],
            text: .constant(""),
            onNext: {}
        )
    }
} 

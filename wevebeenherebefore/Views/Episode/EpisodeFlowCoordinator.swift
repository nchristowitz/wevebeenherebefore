import SwiftUI
import SwiftData

class EpisodeFlowState: ObservableObject {
    @Published var currentStep: EpisodeStep = .emotionRating
    @Published var emotions: [String: Int] = [:]
    @Published var responses: [String: String] = [:] // Changed from [Int: String]
    @Published var episodeTitle: String = ""
    @Published var isShowingExitAlert = false
    
    let promptQuestions = [
        "Describe the episode": "Think about future you as you write this, keep it short but detailed enough",
        "How do you think you'll feel two weeks from now?": "Future reflections help slow you down and see the bigger picture",
        "What about 3 months from now?": "Will this episode still hurt? Will it be a small speed bump?",
        "Let's give this episode a title": "Keep it short but recognizable for future you"
    ]
    
    enum EpisodeStep: Equatable {
        case emotionRating
        case prompt(EpisodePrompt)
        case summary
        
        static func == (lhs: EpisodeStep, rhs: EpisodeStep) -> Bool {
            switch (lhs, rhs) {
            case (.emotionRating, .emotionRating):
                return true
            case (.summary, .summary):
                return true
            case let (.prompt(lhsPrompt), .prompt(rhsPrompt)):
                return lhsPrompt == rhsPrompt
            default:
                return false
            }
        }
    }
    
    var isLastPrompt: Bool {
        guard case .prompt(let current) = currentStep else { return false }
        let prompts = Array(promptQuestions.keys)
        return prompts.lastIndex(of: current.question) == prompts.count - 1
    }
    
    func moveToNext() {
        switch currentStep {
        case .emotionRating:
            currentStep = .prompt(EpisodePrompt.prompts[0])
        case .prompt(let current):
            if let index = EpisodePrompt.prompts.firstIndex(where: { $0.id == current.id }) {
                if index < EpisodePrompt.prompts.count - 1 {
                    currentStep = .prompt(EpisodePrompt.prompts[index + 1])
                } else {
                    currentStep = .summary
                }
            }
        case .summary:
            break
        }
    }
    
    func moveToPrevious() {
        switch currentStep {
        case .emotionRating:
            break
        case .prompt(let current):
            let prompts = Array(promptQuestions.keys)
            if let currentIndex = prompts.firstIndex(of: current.question) {
                if currentIndex == 0 {
                    currentStep = .emotionRating
                } else {
                    currentStep = .prompt(EpisodePrompt.prompts[currentIndex - 1])
                }
            }
        case .summary:
            currentStep = .prompt(EpisodePrompt.prompts.last!)
        }
    }
    
    var shouldShowCloseButton: Bool {
        if case .summary = currentStep {
            return false
        }
        return true
    }
}

struct EpisodeFlowCoordinator: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var state = EpisodeFlowState()
    
    var body: some View {
        NavigationStack {
            Group {
                switch state.currentStep {
                case .emotionRating:
                    EmotionRatingView { emotions in
                        state.emotions = emotions
                        state.moveToNext()
                    }
                    
                case .prompt(let prompt):
                    if prompt.isLast {
                        EpisodeTitlePromptView(
                            prompt: prompt,
                            text: Binding(
                                get: { state.responses[prompt.question] ?? "" },
                                set: { state.responses[prompt.question] = $0 }
                            ),
                            onNext: {
                                state.moveToNext()
                            }
                        )
                    } else {
                        EpisodePromptView(
                            prompt: prompt,
                            text: Binding(
                                get: { state.responses[prompt.question] ?? "" },
                                set: { state.responses[prompt.question] = $0 }
                            ),
                            onNext: {
                                state.moveToNext()
                            }
                        )
                    }
                    
                case .summary:
                    EpisodeSummaryView(
                        emotions: state.emotions,
                        prompts: state.responses,
                        title: state.responses["Let's give this episode a title"] ?? "",
                        onSave: {
                            saveEpisode()
                            dismiss()
                        }
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if state.shouldShowCloseButton {
                        Button {
                            state.isShowingExitAlert = true
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .alert("Are you sure?", isPresented: $state.isShowingExitAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Exit", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("You'll lose any progress if you exit now.")
        }
    }
    
    private func saveEpisode() {
        let title = state.responses[EpisodePrompt.prompts.last?.question ?? ""] ?? ""
        let episode = Episode(
            title: title,
            emotions: state.emotions,
            prompts: state.responses
        )
        modelContext.insert(episode)
    }
}

#Preview {
    EpisodeFlowCoordinator()
        .modelContainer(for: Episode.self, inMemory: true)
} 
import SwiftUI
import SwiftData

class EpisodeFlowState: ObservableObject {
    @Published var currentStep: EpisodeStep = .emotionRating
    @Published var emotions: [String: Int] = [:]
    @Published var responses: [String: String] = [:] // Changed from [Int: String]
    @Published var episodeTitle: String = ""
    @Published var isShowingExitAlert = false

    enum EpisodeStep: Equatable {
        case emotionRating
        case prompt(EpisodePrompt)
        case summary
        case remember
        case resilienceReminders

        static func == (lhs: EpisodeStep, rhs: EpisodeStep) -> Bool {
            switch (lhs, rhs) {
            case (.emotionRating, .emotionRating):
                return true
            case (.summary, .summary):
                return true
            case (.remember, .remember):
                return true
            case (.resilienceReminders, .resilienceReminders):
                return true
            case let (.prompt(lhsPrompt), .prompt(rhsPrompt)):
                return lhsPrompt == rhsPrompt
            default:
                return false
            }
        }
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
            currentStep = .remember
        case .remember:
            currentStep = .resilienceReminders
        case .resilienceReminders:
            break
        }
    }
    
    // Step back from the review screen to the title prompt. Answers live
    // in `responses`, so every prompt keeps what was written.
    func returnToLastPrompt() {
        if let lastPrompt = EpisodePrompt.prompts.last {
            currentStep = .prompt(lastPrompt)
        }
    }

    var shouldShowCloseButton: Bool {
        if case .summary = currentStep {
            return false
        }
        if case .remember = currentStep {
            return false
        }
        if case .resilienceReminders = currentStep {
            return false
        }
        return true
    }
}

struct EpisodeFlowCoordinator: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var state = EpisodeFlowState()
    @State private var savedEpisode: Episode?
    @State private var saveError: String?
    @Query private var allEpisodes: [Episode]

    // Whether the remember step has anything to show: a past episode with a
    // summary or a prediction-vs-reality pair (excluding the one just saved)
    private var hasRememberContent: Bool {
        allEpisodes.contains { episode in
            episode.persistentModelID != savedEpisode?.persistentModelID &&
            (episode.hasSummary || episode.bestPredictionRealityPair != nil)
        }
    }

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
                        title: state.responses[EpisodePrompt.titleQuestion] ?? "",
                        onBack: {
                            state.returnToLastPrompt()
                        },
                        onSave: {
                            // On failure an alert shows and the review stays put
                            guard let episode = saveEpisode() else { return }
                            savedEpisode = episode
                            // Skip remember step if no summarized episodes exist
                            if hasRememberContent {
                                state.moveToNext()
                            } else {
                                state.currentStep = .resilienceReminders
                            }
                        }
                    )

                case .remember:
                    if let episode = savedEpisode {
                        RememberView(currentEpisode: episode) {
                            state.moveToNext()
                        }
                    }

                case .resilienceReminders:
                    ResilienceRemindersView {
                        dismiss()
                    }
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
        .saveErrorAlert($saveError)
    }
    
    // Returns nil if the save failed; the alert explains and the answers
    // stay in `state`, so Save can simply be tapped again
    private func saveEpisode() -> Episode? {
        let title = state.responses[EpisodePrompt.titleQuestion] ?? ""
        let episode = Episode(
            title: title,
            emotions: state.emotions,
            prompts: state.responses
        )
        modelContext.insert(episode)

        // Persist immediately rather than waiting for autosave — the episode
        // is the user's writing and should hit disk before anything else runs
        do {
            try modelContext.save()
        } catch {
            print("❌ Error saving episode: \(error)")
            // Drop the unsaved insert so a retry doesn't create a second copy
            modelContext.rollback()
            saveError = saveErrorMessage(for: error)
            return nil
        }

        // Enhanced notification scheduling with better error handling
        Task {
            // Always check permission first
            await NotificationManager.shared.checkPermission()

            if !NotificationManager.shared.hasPermission {
                // Request permission
                await NotificationManager.shared.requestPermission()

                // Check again after request
                await NotificationManager.shared.checkPermission()
            }

            if NotificationManager.shared.hasPermission {
                let scheduledIDs = NotificationManager.shared.scheduleCheckInNotifications(for: episode)
                episode.notificationIDs = scheduledIDs
            } else {
                print("⚠️ Notifications not scheduled - permission denied")
            }
        }

        return episode
    }
}

#Preview {
    EpisodeFlowCoordinator()
        .modelContainer(for: Episode.self, inMemory: true)
}

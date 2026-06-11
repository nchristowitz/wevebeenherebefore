import SwiftUI
import SwiftData

// Side-by-side of what the user predicted during an episode and what they
// actually wrote when the check-in came due. Used in the RememberView
// carousel and as the verdict moment after completing a check-in.
struct PredictionRealityCard: View {
    let pair: PredictionRealityPair
    var showsEpisodeHeader: Bool = true

    private var realityLabel: String {
        switch pair.checkInType {
        case .twentyFourHour:
            return "A day later"
        case .twoWeek:
            return "2 weeks later"
        case .threeMonth:
            return "3 months later"
        }
    }

    private var topEmotion: (name: String, rating: Int)? {
        pair.episode.emotions
            .filter { $0.value > 0 }
            .max { $0.value < $1.value }
            .map { (name: $0.key, rating: $0.value) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if showsEpisodeHeader {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pair.episode.title)
                            .font(.title2)
                            .fontWeight(.semibold)

                        HStack(spacing: 6) {
                            Text(pair.episode.date, format: .dateTime.month().day().year())

                            if let emotion = topEmotion {
                                Text("·")
                                Text("\(emotion.name) \(emotion.rating)/5")
                            }
                        }
                        .font(.subheadline)
                        .opacity(0.7)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("You predicted")
                        .font(.caption)
                        .textCase(.uppercase)
                        .fontWeight(.semibold)
                        .opacity(0.6)

                    Text(pair.prediction)
                        .font(.body)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text(realityLabel)
                        .font(.caption)
                        .textCase(.uppercase)
                        .fontWeight(.semibold)
                        .opacity(0.6)

                    Text(pair.reality)
                        .font(.body)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    let episode = Episode(
        title: "Big presentation panic",
        emotions: ["Anxiety": 5, "Fear": 3],
        prompts: [
            "How do you think you'll feel about this in 2 weeks?": "I'll probably still be replaying every mistake and everyone will remember how badly it went. This could genuinely affect how the team sees me."
        ]
    )
    episode.date = Calendar.current.date(byAdding: .day, value: -15, to: Date())!

    let checkIn = CheckIn(
        text: "Honestly I had to think hard to even remember what I was so worried about. Nobody has mentioned it once. I did fine.",
        checkInType: .twoWeek,
        episode: episode
    )

    return PredictionRealityCard(
        pair: PredictionRealityPair(
            episode: episode,
            checkInType: .twoWeek,
            prediction: episode.prediction(for: .twoWeek) ?? "",
            reality: checkIn.text,
            realityDate: checkIn.createdAt
        )
    )
    .frame(height: 420)
    .padding()
    .modelContainer(for: [Episode.self, CheckIn.self], inMemory: true)
}

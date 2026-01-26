import SwiftUI
import SwiftData

struct ResilienceRemindersView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Card.createdAt, order: .reverse) private var allCards: [Card]

    let onComplete: () -> Void

    // Store randomized cards to prevent refresh glitch
    @State private var resilienceCards: [Card] = []
    @State private var currentIndex: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                if resilienceCards.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "heart.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("No resilience cards yet")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Add techniques and delights to your toolkit to see them here.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    VStack(spacing: 0) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("From your resilience toolkit")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

                            Text("Swipe through memories, techniques, and delights that have helped you before.")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                        // Carousel
                        TabView(selection: $currentIndex) {
                            ForEach(Array(resilienceCards.enumerated()), id: \.element.id) { index, card in
                                CarouselCardView(card: card)
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .automatic))

                        // Spacer for continue button
                        Color.clear.frame(height: 80)
                    }
                }

                // Continue button
                VStack {
                    Spacer()
                    HStack {
                        if #available(iOS 26.0, *) {
                            Button(action: {
                                onComplete()
                                dismiss()
                            }) {
                                Text("Continue")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .glassEffect()
                            }
                        } else {
                            Button(action: {
                                onComplete()
                                dismiss()
                            }) {
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
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onComplete()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
            }
            .onAppear {
                // Set random cards once on appear to prevent refresh glitch
                if resilienceCards.isEmpty {
                    resilienceCards = Array(allCards.shuffled().prefix(4))
                }
            }
        }
    }
}

// Card view optimized for carousel display
struct CarouselCardView: View {
    let card: Card

    // Check if this is an image-only card (has image, no text)
    private var isImageOnly: Bool {
        card.imageData != nil && card.text.isEmpty
    }

    var body: some View {
        Group {
            if isImageOnly, let imageData = card.imageData, let uiImage = UIImage(data: imageData) {
                // Image-only card - fill the entire container
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                // Card with text (and optional image)
                VStack(alignment: .leading, spacing: 0) {
                    if card.type == .memory, let date = card.date {
                        Text(date, format: .dateTime.month().year())
                            .font(.caption)
                            .textCase(.uppercase)
                            .opacity(0.6)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                    }

                    if let imageData = card.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 20)
                            .padding(.top, card.type == .memory ? 12 : 20)
                    }

                    if !card.text.isEmpty {
                        Text(card.text)
                            .font(.system(size: 28, weight: .regular, design: .default))
                            .kerning(-0.3)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .padding(20)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(card.color)
                .foregroundColor(card.color.contrastingTextColor())
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Card.self, configurations: config)

    // Create sample cards
    let card1 = Card(text: "Deep breathing helps me calm down when I feel anxious. Taking slow, deliberate breaths centers me.", type: .technique, color: .blue)
    let card2 = Card(text: "Watching the sunset from my window", type: .delight, color: .orange)
    let card3 = Card(text: "Going for a walk in nature clears my head and helps me think more clearly about what's bothering me.", type: .technique, color: .green)
    let card4 = Card(text: "Listening to my favorite music", type: .delight, color: .purple)

    container.mainContext.insert(card1)
    container.mainContext.insert(card2)
    container.mainContext.insert(card3)
    container.mainContext.insert(card4)

    return ResilienceRemindersView {
        print("Completed")
    }
    .modelContainer(container)
}

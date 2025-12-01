import SwiftUI
import SwiftData

struct ResilienceRemindersView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Card.createdAt, order: .reverse) private var allCards: [Card]

    let onComplete: () -> Void

    // Store randomized cards to prevent refresh glitch
    @State private var resilienceCards: [Card] = []

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
                    List {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("From your resilience toolkit")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

                            Text("Memories, techniques, and delights that have helped you before.")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                        // Resilience Cards
                        ForEach(resilienceCards) { card in
                            CardView(card: card)
                                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }

                // Continue button - iOS 26 liquid glass style
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

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Card.self, configurations: config)

    // Create sample cards
    let card1 = Card(text: "Deep breathing helps me calm down", type: .technique, color: .blue)
    let card2 = Card(text: "Watching the sunset from my window", type: .delight, color: .orange)
    let card3 = Card(text: "Going for a walk in nature", type: .technique, color: .green)
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

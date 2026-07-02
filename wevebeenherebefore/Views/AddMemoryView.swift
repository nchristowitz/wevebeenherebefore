import SwiftUI

struct AddMemoryView: View {
    @State private var selectedDate = Date()
    @State private var selectedColor: Color
    let existingCard: Card?
    let initialText: String?

    init(existingCard: Card? = nil, initialText: String? = nil) {
        self.existingCard = existingCard
        self.initialText = initialText
        _selectedColor = State(initialValue: existingCard?.color ?? Color(uiColor: .systemGray6))
        _selectedDate = State(initialValue: existingCard?.date ?? Date())
    }

    var body: some View {
        AddCardBaseView(
            type: .memory,
            selectedColor: $selectedColor,
            date: selectedDate,
            existingCard: existingCard,
            initialText: initialText
        ) {
            HStack {
                // Native-style date capsule at the shared accessory height.
                // The compact picker has no size API, so an invisible one
                // sits on top as the tap target and calendar popover.
                ZStack {
                    Text(selectedDate, format: .dateTime.day().month().year())
                        .padding(.horizontal, 16)
                        .frame(height: accessoryControlHeight)
                        .background(Capsule().fill(Color(uiColor: .tertiarySystemFill)))
                        .accessibilityHidden(true)

                    DatePicker(
                        "",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    // Low but above the ~1% hit-testing cutoff; visually
                    // disappears into the styled capsule behind it
                    .opacity(0.05)
                }

                Spacer()

                GlassColorChip(selection: $selectedColor)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}

#Preview {
    AddMemoryView()
} 
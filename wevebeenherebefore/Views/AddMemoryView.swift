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
                GlassAccessoryChip {
                    DatePicker(
                        "",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                }

                Spacer()

                GlassAccessoryChip {
                    ColorPicker("", selection: $selectedColor)
                        .labelsHidden()
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}

#Preview {
    AddMemoryView()
} 
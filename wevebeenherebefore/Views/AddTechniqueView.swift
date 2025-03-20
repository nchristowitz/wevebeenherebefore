import SwiftUI

struct AddTechniqueView: View {
    @State private var selectedColor: Color
    let existingCard: Card?
    
    init(existingCard: Card? = nil) {
        self.existingCard = existingCard
        _selectedColor = State(initialValue: existingCard?.color ?? Color(uiColor: .systemGray6))
    }
    
    var body: some View {
        AddCardBaseView(
            type: .technique,
            selectedColor: $selectedColor,
            existingCard: existingCard
        ) {
            HStack {
                Spacer()
                ColorPicker("", selection: $selectedColor)
                    .labelsHidden()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
    }
}

#Preview {
    AddTechniqueView()
} 
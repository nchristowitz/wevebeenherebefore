import SwiftUI

struct AddTechniqueView: View {
    @State private var selectedColor: Color
    let existingCard: Card?
    
    init(existingCard: Card? = nil) {
        self.existingCard = existingCard
        _selectedColor = State(initialValue: existingCard?.color ?? Card.defaultColor)
    }
    
    var body: some View {
        AddCardBaseView(
            type: .technique,
            selectedColor: $selectedColor,
            existingCard: existingCard
        ) {
            HStack {
                Spacer()

                GlassColorChip(selection: $selectedColor)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}

#Preview {
    AddTechniqueView()
} 
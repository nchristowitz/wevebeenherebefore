import SwiftUI

struct AddTechniqueView: View {
    @State private var selectedColor = Color(uiColor: .systemGray6)
    
    var body: some View {
        AddCardBaseView(type: .technique, selectedColor: $selectedColor) {
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
import SwiftUI

struct AddMemoryView: View {
    @State private var selectedDate = Date()
    @State private var selectedColor = Color(uiColor: .systemGray6)
    
    var body: some View {
        AddCardBaseView(type: .memory, selectedColor: $selectedColor) {
            HStack {
                DatePicker(
                    "",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                
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
    AddMemoryView()
} 
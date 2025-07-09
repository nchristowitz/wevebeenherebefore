import SwiftUI

struct AddCardButton: View {
    @Binding var isShowingDelight: Bool
    @Binding var isShowingMemory: Bool
    @Binding var isShowingTechnique: Bool
    
    var body: some View {
        Menu {
            Button(action: { isShowingDelight = true }) {
                Label("Add Delight", systemImage: "heart.fill")
            }
            .accessibilityLabel("Add Delight card")
            .accessibilityHint("Create a new delight to add to your resilience toolkit")
            
            Button(action: { isShowingMemory = true }) {
                Label("Add Memory", systemImage: "book")
            }
            .accessibilityLabel("Add Memory card")
            .accessibilityHint("Create a new memory to add to your resilience toolkit")
            
            Button(action: { isShowingTechnique = true }) {
                Label("Add Technique", systemImage: "figure.mind.and.body")
            }
            .accessibilityLabel("Add Technique card")
            .accessibilityHint("Create a new technique to add to your resilience toolkit")
        } label: {
            CircularButton(
                systemImage: "plus",
                accessibilityLabel: "Add Card Menu",
                accessibilityHint: "Open menu to add new resilience cards",
                action: {}
            )
        }
        .accessibilityLabel("Add Card Menu")
        .accessibilityHint("Menu with options to add delight, memory, or technique cards")
    }
} 
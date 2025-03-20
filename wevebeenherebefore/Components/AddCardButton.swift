import SwiftUI

struct AddCardButton: View {
    @Binding var isShowingDelight: Bool
    @Binding var isShowingMemory: Bool
    @Binding var isShowingTechnique: Bool
    
    var body: some View {
        Menu {
            Button(action: { isShowingDelight = true }) {
                Label("Add Delight", systemImage: "sparkles")
            }
            
            Button(action: { isShowingMemory = true }) {
                Label("Add Memory", systemImage: "book")
            }
            
            Button(action: { isShowingTechnique = true }) {
                Label("Add Technique", systemImage: "figure.mind.and.body")
            }
        } label: {
            CircularButton(systemImage: "plus", action: {})
        }
    }
} 
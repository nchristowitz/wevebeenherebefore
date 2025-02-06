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
            Image(systemName: "plus")
                .font(.title)
                .fontWeight(.regular)
                .foregroundColor(.primary)
                .frame(width: 60, height: 60)
                .background(.regularMaterial)
                .clipShape(Circle())
                .shadow(radius: 4)
        }
    }
} 
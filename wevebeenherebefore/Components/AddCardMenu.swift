import SwiftUI

struct AddCardMenu: View {
    @Binding var isShowingDelight: Bool
    @Binding var isShowingMemory: Bool
    @Binding var isShowingTechnique: Bool
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            MenuButton(
                title: "Add Delight",
                icon: "heart.fill",
                action: {
                    isPresented = false
                    isShowingDelight = true
                }
            )
            
            MenuButton(
                title: "Add Memory",
                icon: "book",
                action: {
                    isPresented = false
                    isShowingMemory = true
                }
            )
            
            MenuButton(
                title: "Add Technique",
                icon: "figure.mind.and.body",
                action: {
                    isPresented = false
                    isShowingTechnique = true
                }
            )
        }
        .padding(.horizontal)
    }
}
import SwiftUI

struct MenuTray<Content: View>: View {
    let title: String
    @Binding var isPresented: Bool
    let content: () -> Content
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Dimmed background
                if isPresented {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            isPresented = false
                        }
                }
                
                // Tray content
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 36, height: 5)
                            .padding(.top, 8)
                        
                        Text(title)
                            .font(.headline)
                            .padding(.bottom, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    
                    // Content
                    ScrollView {
                        content()
                            .padding(.vertical, 20)
                    }
                }
                .frame(maxHeight: geometry.size.height * 0.7)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
                .offset(y: isPresented ? 0 : geometry.size.height)
                .animation(.spring(response: 0.3), value: isPresented)
            }
            .ignoresSafeArea()
        }
    }
} 
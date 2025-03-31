import SwiftUI

struct MenuTray<Content: View>: View {
    let title: String
    @Binding var isPresented: Bool
    let content: () -> Content
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            let maxHeight = geometry.size.height / 2
            let dragProgress = min(1, max(0, dragOffset / maxHeight))
            let backgroundOpacity = 0.3 * (1 - dragProgress)
            
            ZStack(alignment: .bottom) {
                // Dimmed background that fades with drag
                Color.black.opacity(isPresented ? backgroundOpacity : 0)
                    .ignoresSafeArea()
                    .animation(isDragging ? nil : .easeInOut, value: isPresented)
                    .onTapGesture {
                        isPresented = false
                    }
                
                // Tray content
                VStack(spacing: 0) {
                    // Header with drag indicator
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
                    .background(.white)
                    
                    // Content
                    ScrollView {
                        content()
                            .padding(.vertical, 20)
                    }
                    .frame(idealHeight: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .frame(maxHeight: maxHeight)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
                .offset(y: isPresented ? dragOffset : geometry.size.height)
                .animation(isDragging ? nil : .spring(response: 0.3), value: isPresented)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            // Only allow dragging down
                            dragOffset = max(0, value.translation.height)
                        }
                        .onEnded { value in
                            // Dismiss if dragged more than 1/3 of the way
                            if dragOffset > maxHeight / 3 {
                                isPresented = false
                            }
                            
                            isDragging = false
                            // Reset drag offset with animation
                            withAnimation(.spring(response: 0.3)) {
                                dragOffset = 0
                            }
                        }
                )
            }
            .opacity(isPresented ? 1 : 0)
            .allowsHitTesting(isPresented)
            .ignoresSafeArea()
        }
    }
} 
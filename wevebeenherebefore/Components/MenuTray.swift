import SwiftUI

struct MenuTray<Content: View>: View {
    let title: String
    @Binding var isPresented: Bool
    let content: () -> Content
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            let safeHeight = max(1, geometry.size.height)
            let maxHeight = safeHeight / 2
            let safeDragOffset = max(0, dragOffset)
            let dragProgress = min(1, max(0, safeDragOffset / max(1, maxHeight)))
            let backgroundOpacity = 0.3 * (1 - dragProgress)
            
            ZStack(alignment: .bottom) {
                // Dimmed background that fades with drag
                Color.black.opacity(isPresented ? backgroundOpacity : 0)
                    .ignoresSafeArea()
                    .animation(isDragging ? nil : .easeInOut, value: isPresented)
                    .onTapGesture {
                        isPresented = false
                    }
                    .accessibilityLabel("Dismiss menu")
                    .accessibilityHint("Tap to close the \(title) menu")
                    .accessibilityAddTraits(.isButton)
                
                // Tray content
                VStack(spacing: 0) {
                    // Header with drag indicator
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(Color.secondary.opacity(0.5))
                            .frame(width: 36, height: 5)
                            .padding(.top, 8)
                            .accessibilityLabel("Drag handle")
                            .accessibilityHint("Drag down to dismiss \(title) menu")
                            .accessibilityAddTraits(.allowsDirectInteraction)
                        
                        Text(title)
                            .font(.headline)
                            .padding(.bottom, 8)
                            .accessibilityAddTraits(.isHeader)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Content
                    ScrollView {
                        content()
                            .padding(.vertical, 20)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .accessibilityLabel("\(title) content")
                }
                .frame(maxHeight: maxHeight)
                .background(.thickMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
                .offset(y: isPresented ? min(dragOffset, maxHeight) : geometry.size.height)
                .animation(isDragging ? nil : .spring(response: 0.3), value: isPresented)
                .accessibilityElement(children: .contain)
                .accessibilityAction(named: "Dismiss") {
                    isPresented = false
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            // Only allow dragging down with a limit to prevent invalid frames
                            dragOffset = max(0, min(value.translation.height, maxHeight))
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
            .transition(.opacity)
            .opacity(isPresented ? 1 : 0)
            .allowsHitTesting(isPresented)
            .ignoresSafeArea()
        }
    }
} 

import SwiftUI

struct MenuButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    let isSelected: Bool
    let isFullRounded: Bool
    
    init(
        title: String,
        icon: String,
        isSelected: Bool = false,
        isFullRounded: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.isFullRounded = isFullRounded
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(isFullRounded ? 24 : 12)
        }
    }
} 
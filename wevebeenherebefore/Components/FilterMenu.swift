import SwiftUI

struct FilterOption: Identifiable {
    let id = UUID()
    let title: String
    let type: FilterType
    var isSelected: Bool
}

enum FilterType {
    case memory
    case delight
    case technique
    case imagesOnly
    case dateNewest
    case dateOldest
}

struct FilterMenu: View {
    @Binding var selectedFilter: FilterType?
    @Binding var isPresented: Bool
    
    let options: [FilterOption] = [
        FilterOption(title: "Memories", type: .memory, isSelected: false),
        FilterOption(title: "Delights", type: .delight, isSelected: false),
        FilterOption(title: "Techniques", type: .technique, isSelected: false),
        FilterOption(title: "Images Only", type: .imagesOnly, isSelected: false),
        FilterOption(title: "Newest First", type: .dateNewest, isSelected: false),
        FilterOption(title: "Oldest First", type: .dateOldest, isSelected: false)
    ]
    
    var body: some View {
        HStack(spacing: 8) {
            // Clear filters button
            Button(action: {
                selectedFilter = nil
                isPresented = false
            }) {
                HStack {
                    Image(systemName: "xmark")
                    Text("Clear")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .foregroundColor(selectedFilter == nil ? .primary : .secondary)
                .clipShape(Capsule())
            }
            
            ForEach(options) { option in
                Button(action: {
                    selectedFilter = option.type
                    isPresented = false
                }) {
                    Text(option.title)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .foregroundColor(selectedFilter == option.type ? .primary : .secondary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
} 
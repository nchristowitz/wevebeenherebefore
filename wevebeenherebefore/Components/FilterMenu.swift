import SwiftUI

struct FilterOption: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let type: FilterType
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
        FilterOption(title: "Memories", icon: "book", type: .memory),
        FilterOption(title: "Delights", icon: "heart.fill", type: .delight),
        FilterOption(title: "Techniques", icon: "figure.mind.and.body", type: .technique),
        FilterOption(title: "Images Only", icon: "photo", type: .imagesOnly),
        FilterOption(title: "Oldest First", icon: "arrow.up.circle", type: .dateOldest)
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            if selectedFilter != nil {
                MenuButton(
                    title: "Clear Filters",
                    icon: "xmark.circle.fill",
                    isFullRounded: true,
                    action: {
                        selectedFilter = nil
                        isPresented = false
                    }
                )
            }
            
            ForEach(options) { option in
                MenuButton(
                    title: option.title,
                    icon: option.icon,
                    isSelected: selectedFilter == option.type,
                    isFullRounded: true,
                    action: {
                        if selectedFilter == option.type {
                            // If already selected, deselect it
                            selectedFilter = nil
                        } else {
                            // Otherwise, select it
                            selectedFilter = option.type
                        }
                        isPresented = false
                    }
                )
            }
        }
        .padding(.horizontal)
    }
}

// Add this to the bottom of your FilterMenu.swift file

#Preview("No Filter Selected") {
    FilterMenu(
        selectedFilter: .constant(nil),
        isPresented: .constant(true)
    )
    .padding()
}

#Preview("Memory Filter Selected") {
    FilterMenu(
        selectedFilter: .constant(.memory),
        isPresented: .constant(true)
    )
    .padding()
}

#Preview("With Clear Button") {
    FilterMenu(
        selectedFilter: .constant(.delight),
        isPresented: .constant(true)
    )
    .padding()
}

//
//  SettingsMenu.swift
//  wevebeenherebefore
//
//  Created by Nicholas Christowitz on 27.05.25.
//
import SwiftUI

struct SettingsMenu: View {
    @Binding var selectedFilter: FilterType?
    @Binding var isPresented: Bool
    @State private var isShowingExport = false
    @State private var isShowingImport = false
    
    let filterOptions: [FilterOption] = [
        FilterOption(title: "Memories", icon: "book", type: .memory),
        FilterOption(title: "Delights", icon: "heart.fill", type: .delight),
        FilterOption(title: "Techniques", icon: "figure.mind.and.body", type: .technique),
        FilterOption(title: "Images Only", icon: "photo", type: .imagesOnly)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Filter by section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Filter by")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    if selectedFilter != nil {
                        Button("Clear") {
                            selectedFilter = nil
                            isPresented = false
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                }
                
                FlowingFilterButtons(
                    options: filterOptions,
                    selectedFilter: $selectedFilter,
                    onSelection: {
                        isPresented = false
                    }
                )
            }
            
            // My Data section
            VStack(alignment: .leading, spacing: 12) {
                Text("My Data")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                MenuButton(
                    title: "Export Data",
                    icon: "square.and.arrow.up",
                    action: {
                        isShowingExport = true
                    }
                )
                
                MenuButton(
                    title: "Import Data",
                    icon: "square.and.arrow.down",
                    action: {
                        isShowingImport = true
                    }
                )
            }
        }
        .padding(.horizontal)
        .sheet(isPresented: $isShowingExport) {
            ExportView()
        }
        .sheet(isPresented: $isShowingImport) {
            ImportView()
        }
    }
}

struct FlowingFilterButtons: View {
    let options: [FilterOption]
    @Binding var selectedFilter: FilterType?
    let onSelection: () -> Void
    
    // Native SwiftUI adaptive grid
    let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 8)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(options) { option in
                Button(action: {
                    if selectedFilter == option.type {
                        selectedFilter = nil
                    } else {
                        selectedFilter = option.type
                    }
                    onSelection()
                }) {
                    HStack(spacing: 8  ) {
                        Image(systemName: option.icon)
                            .font(.system(size: 14))
                        Text(option.title)
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(selectedFilter == option.type ? Color.blue.opacity(0.1) : Color(.secondarySystemGroupedBackground))
                    .foregroundColor(selectedFilter == option.type ? .blue : .primary)
                    .cornerRadius(16)
                }
            }
        }
    }
}

#Preview {
    SettingsMenu(selectedFilter: .constant(.memory), isPresented: .constant(true))
}

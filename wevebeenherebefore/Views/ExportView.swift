import SwiftUI
import SwiftData

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Episode.createdAt, order: .reverse) private var episodes: [Episode]
    @Query(sort: \Card.createdAt, order: .reverse) private var cards: [Card]
    
    @State private var selectedFormat: ExportFormat = .markdown
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Export Your Data")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Export all your episodes, cards, notes, and check-ins in an open format you can use anywhere.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                // Data Preview
                VStack(alignment: .leading, spacing: 12) {
                    Text("What will be exported:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        DataPreviewRow(icon: "tornado", title: "Episodes", count: episodes.count)
                        DataPreviewRow(icon: "rectangle.stack", title: "Cards", count: cards.count)
                        DataPreviewRow(icon: "note.text", title: "Notes", count: totalNotes)
                        DataPreviewRow(icon: "checkmark.circle", title: "Check-ins", count: totalCheckIns)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                
                // Format Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Export Format")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            FormatOptionView(
                                format: format,
                                isSelected: selectedFormat == format,
                                onTap: { selectedFormat = format }
                            )
                        }
                    }
                }
                
                Spacer()
                
                // Export Button
                Button(action: exportData) {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text(isExporting ? "Preparing..." : "Export Data")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isExporting || (episodes.isEmpty && cards.isEmpty))
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [url]) {
                    // Dismiss the export view when sharing is complete
                    dismiss()
                }
            }
        }
    }
    
    private var totalNotes: Int {
        episodes.reduce(0) { $0 + $1.notes.count }
    }
    
    private var totalCheckIns: Int {
        episodes.reduce(0) { $0 + $1.checkIns.count }
    }
    
    private func exportData() {
        guard !episodes.isEmpty || !cards.isEmpty else { return }
        
        isExporting = true
        
        Task {
            let url = ExportManager.shared.exportData(
                episodes: episodes,
                cards: cards,
                format: selectedFormat
            )
            
            await MainActor.run {
                isExporting = false
                exportURL = url
                if url != nil {
                    showingShareSheet = true
                }
            }
        }
    }
}

struct DataPreviewRow: View {
    let icon: String
    let title: String
    let count: Int
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}

struct FormatOptionView: View {
    let format: ExportFormat
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(format.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(formatDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
        .foregroundColor(.primary)
    }
    
    private var formatDescription: String {
        switch format {
        case .csv:
            return "Spreadsheet format - perfect for Excel, Google Sheets, etc."
        case .json:
            return "Structured data format - complete backup with all details"
        case .markdown:
            return "Human-readable text format - great for reading and archiving"
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let onComplete: () -> Void
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            if completed {
                onComplete()
            }
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ExportView()
        .modelContainer(for: [Episode.self, Card.self], inMemory: true)
}

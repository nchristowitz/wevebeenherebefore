//
//  ImportView.swift
//  wevebeenherebefore
//
//  Created by Nicholas Christowitz on 03.06.25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var isShowingDocumentPicker = false
    @State private var isImporting = false
    @State private var importResult: ImportResult?
    @State private var importError: Error?
    @State private var showingResult = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Import Your Data")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Import episodes, cards, notes, and check-ins from a previously exported file.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                // Instructions
                VStack(alignment: .leading, spacing: 12) {
                    Text("How to import:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        InstructionRow(number: "1", text: "Export your data from your other device")
                        InstructionRow(number: "2", text: "Share the file to this device (AirDrop, iCloud, etc.)")
                        InstructionRow(number: "3", text: "Tap 'Choose File' below to select the exported file")
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                
                Spacer()
                
                // Import Button
                Button(action: {
                    isShowingDocumentPicker = true
                }) {
                    HStack {
                        if isImporting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "folder")
                        }
                        Text(isImporting ? "Importing..." : "Choose File")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isImporting)
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
        .fileImporter(
            isPresented: $isShowingDocumentPicker,
            allowedContentTypes: [.json, .commaSeparatedText, .plainText],
            onCompletion: handleFileSelection
        )
        .alert("Import Complete", isPresented: $showingResult) {
            Button("OK") {
                if importResult != nil {
                    dismiss() // Only dismiss on success
                }
            }
        } message: {
            if let result = importResult {
                Text("Successfully imported \(result.episodes) episodes, \(result.cards) cards, \(result.notes) notes, and \(result.checkIns) check-ins.")
            } else if let error = importError {
                Text(error.localizedDescription)
            }
        }
    }
    
    private func handleFileSelection(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            importData(from: url)
        case .failure(let error):
            importError = error
            showingResult = true
        }
    }
    
    private func importData(from url: URL) {
        isImporting = true
        
        Task {
            do {
                let result = try await ImportManager.shared.importData(from: url, into: modelContext)
                
                await MainActor.run {
                    isImporting = false
                    importResult = result
                    importError = nil
                    showingResult = true
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    importError = error
                    showingResult = true
                }
            }
        }
    }
}

struct InstructionRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    ImportView()
        .modelContainer(for: [Episode.self, Card.self], inMemory: true)
}

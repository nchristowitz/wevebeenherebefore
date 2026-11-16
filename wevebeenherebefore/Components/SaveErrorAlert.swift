import SwiftUI

// Shown when saving the user's writing fails, so a failure is never
// silent. Editors stay open on failure, keeping the text for another try.
extension View {
    func saveErrorAlert(_ message: Binding<String?>) -> some View {
        alert(
            "Couldn't Save",
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } }
            ),
            presenting: message.wrappedValue
        ) { _ in
            Button("OK", role: .cancel) { }
        } message: { text in
            Text(text)
        }
    }
}

// Message for a failed save: reassure that nothing typed is lost, then
// the underlying reason
func saveErrorMessage(for error: Error) -> String {
    "Your writing is still here, so you can try again.\n\n\(error.localizedDescription)"
}

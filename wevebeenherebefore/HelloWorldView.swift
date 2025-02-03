import SwiftUI

struct HelloWorldView: View {
    var body: some View {
        Text("Hello World")
            .foregroundColor(.red)
            .font(.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    HelloWorldView()
} 
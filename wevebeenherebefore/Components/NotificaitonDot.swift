import SwiftUI

struct NotificationDot: View {
    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 10, height: 10)
    }
}

#Preview {
    NotificationDot()
}

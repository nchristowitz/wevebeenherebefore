import SwiftUI

extension Color {
    func contrastingTextColor() -> Color {
        let components = UIColor(self).cgColor.components ?? [0, 0, 0, 0]
        let brightness = ((components[0] * 299) + (components[1] * 587) + (components[2] * 114)) / 1000
        return brightness > 0.5 ? .black : .white
    }
} 
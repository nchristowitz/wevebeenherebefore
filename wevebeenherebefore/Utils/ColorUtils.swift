import SwiftUI

extension Color {
    // Red, green and blue in sRGB, each 0...1. getRed converts from any
    // color space — grayscale colors like pure white or black have only two
    // components, so reading cgColor.components directly could crash.
    // Wide-gamut (Display P3) values outside sRGB are clamped.
    var sRGBComponents: (red: Double, green: Double, blue: Double) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return (0.5, 0.5, 0.5)
        }
        let clamp = { (value: CGFloat) in Double(min(max(value, 0), 1)) }
        return (clamp(red), clamp(green), clamp(blue))
    }

    func contrastingTextColor() -> Color {
        let rgb = sRGBComponents
        let brightness = (rgb.red * 299 + rgb.green * 587 + rgb.blue * 114) / 1000
        return brightness > 0.5 ? .black : .white
    }
}

// MARK: - Card colors in Dark Mode

extension Color {
    // The card color for the current appearance. Light mode shows the color
    // as chosen; Dark Mode shows its dark version.
    func cardColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkCardVariant : self
    }

    // Text color to use on a card of this color in the current appearance
    func cardTextColor(for colorScheme: ColorScheme) -> Color {
        cardColor(for: colorScheme).contrastingTextColor()
    }

    // The same hue, made dark enough for white text. Works in OKLCH, a
    // color space where equal lightness *looks* equally light across hues,
    // so yellow and blue cards end up equally dark (plain brightness would
    // leave yellows much lighter). Colors already darker than the target
    // are left as chosen.
    var darkCardVariant: Color {
        let rgb = sRGBComponents
        let original = OKLCH(red: rgb.red, green: rgb.green, blue: rgb.blue)

        // Grays settle near Apple's dark card surfaces; colorful cards a
        // little lighter so their hue still reads
        let colorfulness = min(original.chroma / DarkCard.fullColorChroma, 1)
        let targetLightness = DarkCard.neutralLightness
            + (DarkCard.colorLightness - DarkCard.neutralLightness) * colorfulness

        var lightness = min(original.lightness, targetLightness)
        let chroma = min(original.chroma, DarkCard.maxChroma)

        // Darken further until white text has 7:1 contrast — Apple's
        // recommendation for custom foreground and background colors
        var result = OKLCH(lightness: lightness, chroma: chroma, hue: original.hue).displayableRGB()
        while whiteTextContrast(on: result) < 7, lightness > 0.05 {
            lightness -= 0.02
            result = OKLCH(lightness: lightness, chroma: chroma, hue: original.hue).displayableRGB()
        }

        return Color(.sRGB, red: result.red, green: result.green, blue: result.blue, opacity: 1)
    }
}

// Tuning for dark card colors (OKLCH lightness runs 0 black ... 1 white)
private enum DarkCard {
    static let neutralLightness = 0.30   // grays: close to Apple's dark grouped cells
    static let colorLightness = 0.42     // fully colorful cards
    static let fullColorChroma = 0.08    // chroma at which a card counts as fully colorful
    static let maxChroma = 0.13          // keeps dark colors rich but calm, never neon
}

// WCAG contrast ratio of white text on an sRGB background
private func whiteTextContrast(on rgb: (red: Double, green: Double, blue: Double)) -> Double {
    let luminance = 0.2126 * linear(rgb.red) + 0.7152 * linear(rgb.green) + 0.0722 * linear(rgb.blue)
    return 1.05 / (luminance + 0.05)
}

// sRGB gamma ↔ linear light
private func linear(_ c: Double) -> Double {
    c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
}

private func gamma(_ c: Double) -> Double {
    c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055
}

// A color as lightness, chroma (colorfulness) and hue in OKLCH. Conversion
// formulas from Björn Ottosson's OKLab: https://bottosson.github.io/posts/oklab/
private struct OKLCH {
    var lightness: Double
    var chroma: Double
    var hue: Double  // radians

    init(lightness: Double, chroma: Double, hue: Double) {
        self.lightness = lightness
        self.chroma = chroma
        self.hue = hue
    }

    init(red: Double, green: Double, blue: Double) {
        let r = linear(red), g = linear(green), b = linear(blue)

        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)

        let labL = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
        let labA = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
        let labB = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s

        lightness = labL
        chroma = (labA * labA + labB * labB).squareRoot()
        hue = atan2(labB, labA)
    }

    // sRGB for this color, or nil if it's outside what sRGB can show
    private func rgb(chroma: Double) -> (red: Double, green: Double, blue: Double)? {
        let labA = chroma * cos(hue), labB = chroma * sin(hue)

        let l = pow(lightness + 0.3963377774 * labA + 0.2158037573 * labB, 3)
        let m = pow(lightness - 0.1055613458 * labA - 0.0638541728 * labB, 3)
        let s = pow(lightness - 0.0894841775 * labA - 1.2914855480 * labB, 3)

        let r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

        let inGamut = [r, g, b].allSatisfy { $0 >= -0.0001 && $0 <= 1.0001 }
        guard inGamut else { return nil }
        let clamp = { (c: Double) in min(max(gamma(c), 0), 1) }
        return (clamp(r), clamp(g), clamp(b))
    }

    // sRGB for this color, reducing chroma just enough to be displayable
    // (dark colors can't be as colorful as light ones)
    func displayableRGB() -> (red: Double, green: Double, blue: Double) {
        if let rgb = rgb(chroma: chroma) { return rgb }

        var low = 0.0, high = chroma
        for _ in 0..<16 {
            let mid = (low + high) / 2
            if rgb(chroma: mid) != nil { low = mid } else { high = mid }
        }
        return rgb(chroma: low) ?? (lightness, lightness, lightness)
    }
}

// MARK: - Photos in Dark Mode

// Slightly darkens photos in Dark Mode so bright areas don't glow against
// the dark interface, as Apple's Dark Mode guidelines suggest for content
// images. Light mode shows photos untouched.
private struct DarkModePhotoDimming: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    // Share of brightness kept in Dark Mode (1 = untouched)
    private let darkModeBrightness = 0.88

    func body(content: Content) -> some View {
        content.colorMultiply(colorScheme == .dark ? Color(white: darkModeBrightness) : .white)
    }
}

extension View {
    func dimmedInDarkMode() -> some View {
        modifier(DarkModePhotoDimming())
    }
}

import SwiftUI

/// Fresh native design language for the app — deliberately not a port of the
/// research site's editorial (Playfair Display / cream-terracotta-sage)
/// branding. Leans on system typography, SF Symbols, and standard iOS
/// materials/colors so the app feels at home on the platform.
enum Theme {
    /// Ball colors cycle through these rather than a single accent, echoing
    /// the visual variety of real TOTO number balls without literally
    /// theming the app around them.
    static let ballPalette: [Color] = [.blue, .red, .green, .orange, .purple, .teal]

    static func ballColor(for number: Int) -> Color {
        ballPalette[number % ballPalette.count]
    }

    static let positiveEV = Color.green
    static let negativeEV = Color.red
    static let cardCornerRadius: CGFloat = 16
}

/// A single TOTO number rendered as a filled circle, used throughout Home,
/// History, and the Numbers library.
struct LotteryBallView: View {
    let number: Int
    var size: CGFloat = 44
    var isAdditional: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(isAdditional ? Color.secondary.opacity(0.25) : Theme.ballColor(for: number).opacity(0.85))
            Text("\(number)")
                .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                .foregroundStyle(isAdditional ? Color.primary : Color.white)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(isAdditional ? "Additional number \(number)" : "Number \(number)")
    }
}

/// Standard card container used across feature screens for a consistent
/// grouped-content look without a custom theme system.
struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardBackground())
    }
}

extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// SF Symbol + tint per myth category (design response §3, replaces emoji).
/// The truth green is a single shade across all categories.
struct CategoryStyle {
    let symbol: String
    let tint: Color

    static let truthGreen = Color(hex: 0x34D178)

    static func forKey(_ key: String?) -> CategoryStyle {
        switch key {
        case "randomness": return CategoryStyle(symbol: "die.face.5.fill", tint: Color(hex: 0x8B7CF6))
        case "picking":    return CategoryStyle(symbol: "number.square.fill", tint: Color(hex: 0x2FBDB3))
        case "money":      return CategoryStyle(symbol: "banknote.fill", tint: Color(hex: 0xE6A23C))
        case "mind":       return CategoryStyle(symbol: "brain.head.profile", tint: Color(hex: 0xEF7FA4))
        default:           return CategoryStyle(symbol: "sparkles", tint: Color(hex: 0x8B7CF6))
        }
    }
}

/// Per-page onboarding palette (design response §1). Saturated light
/// background + dark ink, in myth order. Deliberately not the category tints.
struct CarouselPalette {
    let bg: Color
    let ink: Color

    static let pages: [CarouselPalette] = [
        CarouselPalette(bg: Color(hex: 0xFFD84D), ink: Color(hex: 0x231A00)),
        CarouselPalette(bg: Color(hex: 0xA8DCFF), ink: Color(hex: 0x07304E)),
        CarouselPalette(bg: Color(hex: 0xFFC9D9), ink: Color(hex: 0x571130)),
        CarouselPalette(bg: Color(hex: 0xD4C6FF), ink: Color(hex: 0x2A1A62)),
        CarouselPalette(bg: Color(hex: 0xB9ECC4), ink: Color(hex: 0x0B3F22)),
    ]

    static func page(_ index: Int) -> CarouselPalette {
        pages[((index % pages.count) + pages.count) % pages.count]
    }
}

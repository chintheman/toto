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

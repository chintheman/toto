import SwiftUI

/// The app's 5 top-level destinations, in nav-bar order.
enum AppTab: Int, CaseIterable, Identifiable {
    case home, history, numbers, budget, learn

    var id: Int { rawValue }

    /// "Numbers" uses a sparkle (trivia/discovery-flavored, deliberately
    /// not a literal number glyph) rather than the old Picks tab's meaning
    /// for the same symbol.
    var symbolName: String {
        switch self {
        case .home: return "house.fill"
        case .history: return "clock"
        case .numbers: return "sparkles"
        case .budget: return "function"
        case .learn: return "book.fill"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .home: return "Home"
        case .history: return "History"
        case .numbers: return "Numbers"
        case .budget: return "Budget"
        case .learn: return "Learn"
        }
    }
}

/// Lets a pushed screen (currently only the full-bleed Number Reel) request
/// a light-icon variant of the floating nav bar for its dark background,
/// without threading that state explicitly through every navigation layer.
enum NavBarAppearance: Equatable {
    case light
    case dark
}

private struct NavBarAppearanceKey: PreferenceKey {
    static let defaultValue: NavBarAppearance = .light
    /// All 5 tabs stay mounted at once (see `MainTabView`), so more than
    /// one subtree can report a value here — including a background tab
    /// that happens to have the Reel pushed on its own stack. Only the
    /// active tab's contribution should ever count (enforced by
    /// `tabContent` forcing inactive branches to `.light`), so this just
    /// needs to let a single `.dark` anywhere win rather than take
    /// whichever sibling happens to be evaluated last.
    static func reduce(value: inout NavBarAppearance, nextValue: () -> NavBarAppearance) {
        if nextValue() == .dark { value = .dark }
    }
}

extension View {
    /// Marks this screen's preferred nav bar tint. Call once per screen;
    /// the value clears back to `.light` when the screen leaves the
    /// hierarchy since `MainTabView` only ever sees the currently-visible
    /// tab's preference.
    func navBarAppearance(_ appearance: NavBarAppearance) -> some View {
        preference(key: NavBarAppearanceKey.self, value: appearance)
    }

    func onNavBarAppearanceChange(_ action: @escaping (NavBarAppearance) -> Void) -> some View {
        onPreferenceChange(NavBarAppearanceKey.self, perform: action)
    }

    /// For a tab kept mounted-but-hidden alongside the active one (see
    /// `MainTabView`): discards whatever nav-bar-appearance value its
    /// descendants reported (e.g. a Number Reel left pushed on that tab's
    /// own stack) so only the currently active tab can ever affect the
    /// shared nav bar. No-op when `isActive` is true.
    func suppressNavBarAppearance(unless isActive: Bool) -> some View {
        transformPreference(NavBarAppearanceKey.self) { value in
            if !isActive { value = .light }
        }
    }

    /// Reserves clearance for the floating nav pill at the bottom of a
    /// scrollable screen. The pill is an absolutely positioned overlay in
    /// `MainTabView`, not a real safe area, so a List or ScrollView has no
    /// way to know its own trailing content sits underneath it without
    /// this — needed on every tab root *and* every pushed detail screen,
    /// since the pill stays visible at any navigation depth. Works on both
    /// List and ScrollView (safeAreaInset applies to either), so it's the
    /// one thing to reach for instead of ad hoc trailing padding.
    func floatingNavBarClearance() -> some View {
        safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 84)
        }
    }
}

/// Icon-only floating "liquid glass" pill nav bar — replaces the system
/// TabView chrome app-wide. Inset from the screen edges, frosted, active
/// tab rendered as a filled circle behind its icon.
struct FloatingNavBar: View {
    @Binding var selection: AppTab
    var appearance: NavBarAppearance = .light

    private var inactiveColor: Color {
        appearance == .dark ? .white.opacity(0.75) : Color(.systemGray)
    }

    private var activeTint: Color {
        appearance == .dark ? .white : .accentColor
    }

    private var activePillFill: Color {
        appearance == .dark ? .white.opacity(0.22) : .accentColor.opacity(0.14)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let isActive = tab == selection
                Button {
                    selection = tab
                } label: {
                    ZStack {
                        Circle()
                            .fill(isActive ? activePillFill : .clear)
                            .frame(width: 46, height: 46)
                        Image(systemName: tab.symbolName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(isActive ? activeTint : inactiveColor)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.accessibilityLabel)
                .accessibilityAddTraits(isActive ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 64)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(Color.white.opacity(appearance == .dark ? 0.18 : 0.32))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(Color.white.opacity(appearance == .dark ? 0.35 : 0.55), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(appearance == .dark ? 0.25 : 0.14), radius: 15, x: 0, y: 10)
        )
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
    }
}

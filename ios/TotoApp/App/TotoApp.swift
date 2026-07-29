import SwiftUI

@main
struct TotoApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if appState.hasCompletedOnboarding {
            MainTabView()
        } else {
            OnboardingCarouselView {
                appState.hasCompletedOnboarding = true
            }
        }
    }
}

/// Design iteration 1.1.0: Home · History (Draws-only, Numbers split out
/// to its own tab) · Numbers (hub + reel) · Budget (was Calculator, now
/// also owns the locked Strategies/Picks toggle) · Learn. A custom
/// floating "liquid glass" pill replaces the system TabView chrome
/// app-wide, so each tab's content is kept alive in a ZStack (preserving
/// scroll position and push state across switches, like TabView does)
/// rather than swapped in and out.
struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var navBarAppearance: NavBarAppearance = .light

    var body: some View {
        @Bindable var appState = appState
        ZStack(alignment: .bottom) {
            ZStack {
                tabContent(.home)
                tabContent(.history)
                tabContent(.numbers)
                tabContent(.budget)
                tabContent(.learn)
            }
            .ignoresSafeArea(.keyboard)

            FloatingNavBar(selection: $appState.selectedTab, appearance: navBarAppearance)
        }
        .onNavBarAppearanceChange { navBarAppearance = $0 }
    }

    @ViewBuilder
    private func tabContent(_ tab: AppTab) -> some View {
        let isActive = tab == appState.selectedTab
        Group {
            switch tab {
            case .home: HomeView()
            case .history: HistoryView()
            case .numbers: NumbersHubView()
            case .budget: CalculatorView()
            case .learn: LearnView()
            }
        }
        .opacity(isActive ? 1 : 0)
        .allowsHitTesting(isActive)
        .accessibilityHidden(!isActive)
        // Only the active tab's nav-bar-appearance signal should ever
        // reach MainTabView — a background tab that happens to have the
        // Reel pushed on its own stack must not be able to flip the nav
        // bar dark while some other tab is on screen.
        .suppressNavBarAppearance(unless: isActive)
    }
}

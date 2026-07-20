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

/// Design-changes §1: Home · History (with Numbers folded in) ·
/// Calculator · Picks, plus Learn as the 5th tab since Picks ships.
struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(1)

            CalculatorView()
                .tabItem { Label("Calculator", systemImage: "function") }
                .tag(2)

            PicksView()
                .tabItem { Label("Picks", systemImage: "sparkles") }
                .tag(3)

            LearnView()
                .tabItem { Label("Learn", systemImage: "lightbulb.fill") }
                .tag(4)
        }
    }
}

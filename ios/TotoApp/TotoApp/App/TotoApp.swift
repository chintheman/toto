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

struct MainTabView: View {
    @State private var budgetState = BudgetState()

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            CalculatorView(budgetState: budgetState)
                .tabItem { Label("Calculator", systemImage: "function") }

            PicksView(budgetState: budgetState)
                .tabItem { Label("Picks", systemImage: "star.fill") }
        }
    }
}

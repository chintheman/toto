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
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            NumbersGridView()
                .tabItem { Label("Numbers", systemImage: "number.circle.fill") }

            LearnView()
                .tabItem { Label("Learn", systemImage: "lightbulb.fill") }

            CalculatorView()
                .tabItem { Label("Calculator", systemImage: "function") }
        }
    }
}

import SwiftUI

/// Mandatory, full-screen, swipeable first-launch carousel — the "Spotify
/// Wrapped" style educational core of the app. Shown once (gated by
/// AppState.hasCompletedOnboarding), also reachable later from Learn.
struct OnboardingCarouselView: View {
    let onFinished: () -> Void

    @State private var fallacies: [Fallacy] = []
    @State private var currentPage = 0
    @State private var isLoading = true
    @State private var loadError: String?

    private let repository = FallaciesRepository()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black, .indigo.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(.white)
            } else if let loadError {
                onboardingLoadFailure(loadError)
            } else {
                TabView(selection: $currentPage) {
                    ForEach(Array(fallacies.enumerated()), id: \.element.id) { index, fallacy in
                        FallacyCardView(fallacy: fallacy)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .overlay(alignment: .topTrailing) {
                    if currentPage == fallacies.count - 1 {
                        Button("Done") { onFinished() }
                            .buttonStyle(.borderedProminent)
                            .padding()
                    } else {
                        Button("Skip") { onFinished() }
                            .foregroundStyle(.white.opacity(0.7))
                            .padding()
                    }
                }
            }
        }
        .task { await load() }
    }

    private func onboardingLoadFailure(_ message: String) -> some View {
        VStack(spacing: 16) {
            Text("Couldn't load")
                .font(.headline)
                .foregroundStyle(.white)
            Text(message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
            Button("Continue anyway") { onFinished() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func load() async {
        do {
            fallacies = try await repository.onboardingFallacies()
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}

struct FallacyCardView: View {
    let fallacy: Fallacy

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text(fallacy.emoji ?? "🎲")
                .font(.system(size: 64))

            Text(fallacy.mythStatement)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .strikethrough(color: .white.opacity(0.5))

            Text(fallacy.verdictLabel.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.green.opacity(0.2), in: Capsule())

            Text(fallacy.explanationBody)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 32)

            if let stat = fallacy.statCallout {
                Text(stat)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()
            Spacer()
        }
        .padding()
    }
}

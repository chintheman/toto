import SwiftUI

/// Design-changes §6: full-screen first-launch carousel. Dark gradient,
/// segmented progress bar (not dots), myth → verdict → why structure,
/// quiet Skip. Skippable — the same content stays available in Learn.
struct OnboardingCarouselView: View {
    let onFinished: () -> Void

    @State private var fallacies: [Fallacy] = []
    @State private var currentPage = 0
    @State private var isLoading = true
    @State private var loadError: String?

    private let repository: FallaciesRepository

    init(repository: FallaciesRepository = FallaciesRepository(), onFinished: @escaping () -> Void) {
        self.repository = repository
        self.onFinished = onFinished
    }

    static let backgroundGradient = LinearGradient(
        colors: [Color(red: 0.043, green: 0.043, blue: 0.071), Color(red: 0.169, green: 0.165, blue: 0.333)],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        ZStack {
            Self.backgroundGradient
                .ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(.white)
            } else if let loadError {
                onboardingLoadFailure(loadError)
            } else {
                VStack(spacing: 0) {
                    progressBar
                    header
                    TabView(selection: $currentPage) {
                        ForEach(Array(fallacies.enumerated()), id: \.element.id) { index, fallacy in
                            FallacyPageView(fallacy: fallacy)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    footer
                }
            }
        }
        .task { await load() }
    }

    private var progressBar: some View {
        HStack(spacing: 5) {
            ForEach(fallacies.indices, id: \.self) { index in
                Capsule()
                    .fill(index <= currentPage ? Color.white : Color.white.opacity(0.2))
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .animation(.easeInOut(duration: 0.3), value: currentPage)
    }

    private var header: some View {
        HStack {
            Text("MYTH \(currentPage + 1) OF \(fallacies.count)")
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.45))
            Spacer()
            Button("Skip") { onFinished() }
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                if currentPage < fallacies.count - 1 {
                    withAnimation { currentPage += 1 }
                } else {
                    onFinished()
                }
            } label: {
                Text(currentPage == fallacies.count - 1 ? "Done" : "Next myth")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Color(red: 0.043, green: 0.043, blue: 0.071))
            }
            Text("Review these anytime in the Learn tab")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
    }

    private func onboardingLoadFailure(_ message: String) -> some View {
        VStack(spacing: 16) {
            Text("Couldn't load")
                .font(.headline)
                .foregroundStyle(.white)
            Text(message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
            Button("Retry") { Task { await load() } }
                .buttonStyle(.bordered)
                .tint(.white)
            Button("Continue anyway") { onFinished() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func load() async {
        isLoading = true
        loadError = nil
        do {
            fallacies = try await repository.onboardingFallacies()
            if fallacies.isEmpty {
                loadError = "No content available yet."
            }
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}

/// One myth page: tinted emoji circle + THE MYTH chip → myth quote (no
/// strikethrough) → THE TRUTH divider → green truth headline (the
/// takeaway) → body → mono stat chip. Shared with Learn's detail view.
struct FallacyPageView: View {
    let fallacy: Fallacy

    private static let tints: [Color] = [
        Color(red: 1.0, green: 0.54, blue: 0.4).opacity(0.18),
        Color(red: 0.5, green: 0.83, blue: 0.98).opacity(0.16),
        Color(red: 0.96, green: 0.56, blue: 0.69).opacity(0.16),
        Color(red: 0.7, green: 0.62, blue: 0.86).opacity(0.18),
        Color(red: 1.0, green: 0.84, blue: 0.31).opacity(0.16),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Self.tints[abs(fallacy.displayOrder) % Self.tints.count])
                    Text(fallacy.emoji ?? "🎲").font(.system(size: 26))
                }
                .frame(width: 52, height: 52)

                Text("THE MYTH")
                    .font(.caption2.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(Color(red: 1.0, green: 0.54, blue: 0.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color(red: 1.0, green: 0.32, blue: 0.32).opacity(0.14), in: Capsule())
            }

            Text(fallacy.mythStatement)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.top, 16)

            HStack(spacing: 10) {
                Rectangle().fill(.white.opacity(0.15)).frame(height: 1)
                Text("THE TRUTH")
                    .font(.caption2.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(Color(red: 0.29, green: 0.87, blue: 0.5))
                    .fixedSize()
                Rectangle().fill(.white.opacity(0.15)).frame(height: 1)
            }
            .padding(.vertical, 24)

            Text(fallacy.truthHeadline)
                .font(.system(size: 21, weight: .heavy))
                .foregroundStyle(Color(red: 0.29, green: 0.87, blue: 0.5))

            Text(fallacy.explanationBody)
                .font(.subheadline)
                .lineSpacing(4)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.top, 10)

            if let stat = fallacy.statCallout {
                Text(stat)
                    .font(.caption.monospaced())
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.12)))
                    .padding(.top, 18)
            }

            Spacer()
        }
        .padding(.horizontal, 28)
    }
}

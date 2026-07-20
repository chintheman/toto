import SwiftUI

/// Design-changes §6: replay hero, "every myth, busted" list (no
/// strikethrough, green verdict), rows open the full dark myth card.
struct LearnView: View {
    @State private var fallacies: [Fallacy] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showOnboardingReplay = false

    private let repository: FallaciesRepository

    init(repository: FallaciesRepository = FallaciesRepository()) {
        self.repository = repository
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showOnboardingReplay = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "play.rectangle.fill")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Replay the intro").font(.subheadline.bold())
                                Text("All \(fallacies.filter(\.inOnboardingCarousel).count) myths, 2 minutes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Every Myth, Busted") {
                    if let loadError, fallacies.isEmpty {
                        // §7: no silent failure — visible error + retry.
                        VStack(alignment: .leading, spacing: 8) {
                            Text(loadError).font(.caption).foregroundStyle(.secondary)
                            Button("Retry") { Task { await load() } }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    ForEach(fallacies) { fallacy in
                        NavigationLink(value: fallacy) {
                            HStack(spacing: 12) {
                                Text(fallacy.emoji ?? "")
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fallacy.mythStatement)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(2)
                                    Text(fallacy.verdictLabel)
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Learn")
            .navigationDestination(for: Fallacy.self) { fallacy in
                FallacyDetailView(fallacy: fallacy)
            }
            .overlay {
                if isLoading { ProgressView() }
            }
            .task { await load() }
            .fullScreenCover(isPresented: $showOnboardingReplay) {
                OnboardingCarouselView { showOnboardingReplay = false }
            }
        }
    }

    private func load() async {
        isLoading = true
        loadError = nil
        do {
            fallacies = try await repository.allFallacies()
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }
}

struct FallacyDetailView: View {
    let fallacy: Fallacy

    var body: some View {
        ScrollView {
            FallacyPageView(fallacy: fallacy)
                .frame(minHeight: 560)
        }
        .background(OnboardingCarouselView.backgroundGradient.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

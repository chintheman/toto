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

                if let loadError, fallacies.isEmpty {
                    // §7: no silent failure. Visible error and retry.
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(loadError).font(.caption).foregroundStyle(.secondary)
                            Button("Retry") { Task { await load() } }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }

                ForEach(groupedFallacies) { group in
                    Section(group.category) {
                        ForEach(group.items) { fallacy in
                            NavigationLink(value: fallacy) {
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

    /// Section order for the grouped list. Any category not listed here is
    /// appended alphabetically after these.
    private let categoryOrder = ["Randomness & memory", "Picking numbers", "Money & value", "Mind & fairness"]

    private var groupedFallacies: [FallacyGroup] {
        let groups = Dictionary(grouping: fallacies) { $0.category ?? "More myths" }
        var result: [FallacyGroup] = []
        for name in categoryOrder {
            if let items = groups[name], !items.isEmpty {
                result.append(FallacyGroup(category: name, items: items))
            }
        }
        for name in groups.keys.sorted() where !categoryOrder.contains(name) {
            if let items = groups[name] {
                result.append(FallacyGroup(category: name, items: items))
            }
        }
        return result
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

struct FallacyGroup: Identifiable {
    let category: String
    let items: [Fallacy]
    var id: String { category }
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

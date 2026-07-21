import SwiftUI

/// Design response §2/§3: dark glowing "Replay" hero, category sections with
/// SF Symbol tiles (no emoji), clean rows, dark focus-mode detail cards.
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
                replayHero

                if let loadError, fallacies.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(loadError).font(.caption).foregroundStyle(.secondary)
                            Button("Retry") { Task { await load() } }.buttonStyle(.borderedProminent)
                        }
                    }
                }

                ForEach(groupedFallacies) { group in
                    Section {
                        ForEach(group.items) { fallacy in
                            NavigationLink(value: fallacy) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(fallacy.mythStatement)
                                        .font(.system(size: 13, weight: .semibold))
                                        .lineLimit(2)
                                    Text(fallacy.verdictLabel)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(Color(hex: 0x28A745))
                                }
                            }
                        }
                    } header: {
                        categoryHeader(group)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Learn")
            .navigationDestination(for: Fallacy.self) { fallacy in
                FallacyDetailView(fallacy: fallacy)
            }
            .overlay { if isLoading { ProgressView() } }
            .task { await load() }
            .fullScreenCover(isPresented: $showOnboardingReplay) {
                OnboardingCarouselView { showOnboardingReplay = false }
            }
        }
    }

    private var replayHero: some View {
        Section {
            Button { showOnboardingReplay = true } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.12))
                        Image(systemName: "play.fill").foregroundStyle(.white)
                    }
                    .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Replay the intro").font(.subheadline.bold()).foregroundStyle(.white)
                        Text("All \(fallacies.filter(\.inOnboardingCarousel).count) myths, 2 minutes")
                            .font(.caption).foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.white.opacity(0.4))
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0x0A0A10))
                        RadialGradient(colors: [Color(hex: 0x4B3FA6).opacity(0.6), .clear],
                                       center: .topLeading, startRadius: 0, endRadius: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                )
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }

    private func categoryHeader(_ group: FallacyGroup) -> some View {
        let style = group.items.first?.style ?? CategoryStyle.forKey(nil)
        return HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7).fill(style.tint.opacity(0.12))
                Image(systemName: style.symbol).font(.footnote).foregroundStyle(style.tint)
            }
            .frame(width: 26, height: 26)
            Text(group.category).font(.footnote.weight(.semibold)).tracking(0.5)
        }
        .textCase(nil)
    }

    private let categoryOrder = [
        "You think numbers run hot, cold, or overdue",
        "You think the way you pick changes your odds",
        "You think there's a smarter way to spend",
        "You think a fair game is a good bet",
    ]

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
            MythDetailCard(fallacy: fallacy)
                .padding()
        }
        .background(Color(hex: 0x05050A).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

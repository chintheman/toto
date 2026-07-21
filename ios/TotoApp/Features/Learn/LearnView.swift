import SwiftUI

/// Soft-indigo "Replay" hero, bold first-person myth category headers keyed
/// off category_key, and myth detail that opens in the same light,
/// Wrapped-style format as the onboarding carousel.
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
        // Middle ground: a soft indigo gradient in the carousel's colour world
        // (and the app icon's), rather than the near-black slab that clashed
        // with the rest of the light UI.
        let ink = Color(hex: 0x2A1A62)
        return Section {
            Button { showOnboardingReplay = true } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Color(hex: 0x4B3FA6))
                        Image(systemName: "play.fill").font(.subheadline).foregroundStyle(.white)
                    }
                    .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Replay the intro").font(.subheadline.bold()).foregroundStyle(ink)
                        Text("All \(fallacies.filter(\.inOnboardingCarousel).count) myths, about 2 minutes")
                            .font(.caption).foregroundStyle(ink.opacity(0.65))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(ink.opacity(0.4))
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(colors: [Color(hex: 0xE8E1FF), Color(hex: 0xD4C6FF)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 16)
                )
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }

    private func categoryHeader(_ group: FallacyGroup) -> some View {
        let style = group.items.first?.style ?? CategoryStyle.forKey(nil)
        return HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(style.tint.opacity(0.15))
                Image(systemName: style.symbol).font(.title3).foregroundStyle(style.tint)
            }
            .frame(width: 42, height: 42)
            Text(group.category)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .textCase(nil)
        .padding(.top, 10)
        .padding(.bottom, 2)
    }

    // Category display order, keyed off the stable `category_key`. Titles come
    // from Fallacy.categoryTitle, so they're code-driven (no DB dependency).
    private let categoryKeyOrder = ["randomness", "picking", "money", "mind"]

    private var groupedFallacies: [FallacyGroup] {
        let groups = Dictionary(grouping: fallacies) { $0.categoryKey ?? "other" }
        var result: [FallacyGroup] = []
        for key in categoryKeyOrder {
            if let items = groups[key], !items.isEmpty {
                let sorted = items.sorted { $0.displayOrder < $1.displayOrder }
                result.append(FallacyGroup(category: sorted[0].categoryTitle, items: sorted))
            }
        }
        // Any unknown category keys go last, alphabetically.
        let known = Set(categoryKeyOrder)
        for key in groups.keys.sorted() where !known.contains(key) {
            if let items = groups[key] {
                result.append(FallacyGroup(category: items[0].categoryTitle, items: items))
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

/// Opens a single myth in the SAME light, Wrapped-style format as the
/// onboarding carousel: saturated background, vignette (for onboarding
/// myths), bold myth line, marker-highlighted truth, body, and stat pill.
struct FallacyDetailView: View {
    let fallacy: Fallacy

    private var palette: CarouselPalette { CarouselPalette.forCategory(fallacy.categoryKey) }

    var body: some View {
        ZStack {
            palette.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 8)

                    Text(fallacy.categoryTitle.uppercased())
                        .font(.caption.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(palette.ink.opacity(0.55))
                        .multilineTextAlignment(.center)

                    if fallacy.inOnboardingCarousel {
                        MythVignette(index: fallacy.displayOrder - 1, palette: palette)
                            .frame(height: 140)
                    }

                    Text(fallacy.mythStatement)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(palette.ink)
                        .multilineTextAlignment(.center)

                    MarkerText(text: fallacy.truthHeadline, ink: palette.ink)

                    Text(fallacy.explanationBody)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(palette.ink.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)

                    if let stat = fallacy.statCallout {
                        Text(stat)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(palette.ink)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.white.opacity(0.55), in: Capsule())
                            .overlay(Capsule().stroke(palette.ink, lineWidth: 2))
                    }

                    Spacer(minLength: 28)
                }
                .padding(.horizontal, 28)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

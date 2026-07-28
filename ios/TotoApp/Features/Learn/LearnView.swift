import SwiftUI

/// Redesign (design handoff "learn-tab-8b"): four "Big Four" cover cards
/// (album-art style, one TOTO ball each) followed by the four myth
/// collections as a numbered list, with the onboarding replay entry demoted
/// to the bottom. Only this list screen changes — tapping into a myth still
/// opens the existing FallacyDetailView (unchanged, below).
struct LearnView: View {
    @State private var fallacies: [Fallacy] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showOnboardingReplay = false

    private let repository: FallaciesRepository

    init(repository: FallaciesRepository = FallaciesRepository()) {
        self.repository = repository
    }

    private let pageBackground = Color(hex: 0xFBFAF8)
    private let ink = Color(hex: 0x14161A)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let loadError, fallacies.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(loadError).font(.subheadline).foregroundStyle(.secondary)
                            Button("Retry") { Task { await load() } }.buttonStyle(.borderedProminent)
                        }
                        .padding(.top, 12)
                    } else if !fallacies.isEmpty {
                        titleBlock
                        sectionHeader("The big four")
                            .padding(.top, 16)
                        bigFourGrid
                        sectionHeader("Collections")
                            .padding(.top, 26)
                        collectionsList
                        replayCard
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 22)
            }
            .background(pageBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Fallacy.self) { fallacy in
                FallacyDetailView(fallacy: fallacy)
            }
            .navigationDestination(for: LearnCollection.self) { collection in
                CollectionListView(
                    title: collection.title,
                    fallacies: (collectionSlugs[collection.categoryKey] ?? [])
                        .compactMap { slug in fallacies.first { $0.slug == slug } }
                )
            }
            .overlay { if isLoading { ProgressView() } }
            .task { await load() }
            .fullScreenCover(isPresented: $showOnboardingReplay) {
                OnboardingCarouselView { showOnboardingReplay = false }
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Learn")
                .font(.system(size: 32, weight: .heavy))
                .tracking(-0.8)
                .foregroundStyle(ink)
                .padding(.top, 12)
            Text("Eight beliefs almost every player holds, and what the maths actually says.")
                .font(.system(size: 13.5))
                .foregroundStyle(ink.opacity(0.55))
                .lineSpacing(4)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(ink.opacity(0.45))
            Rectangle().fill(ink.opacity(0.1)).frame(height: 1)
        }
    }

    private var bigFourGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 14) {
            ForEach(bigFourCards) { card in
                if let fallacy = fallacies.first(where: { $0.slug == card.id }) {
                    NavigationLink(value: fallacy) {
                        bigFourCardView(card)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func bigFourCardView(_ card: BigFourCard) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [card.gradientTop, card.gradientBottom], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .aspectRatio(1, contentMode: .fit)
                    .shadow(color: card.gradientBottom.opacity(card.shadowOpacity), radius: 10, x: 0, y: 8)
                Circle()
                    .fill(Color.white)
                    .frame(width: 66, height: 66)
                    .overlay(
                        Text(card.ballGlyph)
                            .font(.system(size: card.ballGlyph.count > 1 ? 26 : 30, weight: .heavy))
                            .foregroundStyle(card.ink)
                    )
            }
            Text(card.title)
                .font(.system(size: 14.5, weight: .bold))
                .foregroundStyle(ink)
                .lineLimit(2)
                .padding(.top, 10)
            Text(card.verdict)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color(hex: 0x1A7F37))
                .padding(.top, 3)
        }
    }

    private var collectionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(collections.enumerated()), id: \.element) { index, collection in
                NavigationLink(value: collection) {
                    collectionRow(collection, index: index + 1, isLast: index == collections.count - 1)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func collectionRow(_ collection: LearnCollection, index: Int, isLast: Bool) -> some View {
        let style = CategoryStyle.forKey(collection.categoryKey)
        return VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text(String(format: "%02d", index))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(ink.opacity(0.35))
                    .frame(width: 20, alignment: .leading)
                RoundedRectangle(cornerRadius: 9)
                    .fill(style.tint)
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: style.symbol)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(collection.title).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(ink)
                    Text(collection.meta).font(.system(size: 11.5)).foregroundStyle(ink.opacity(0.5))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 15, weight: .bold)).foregroundStyle(ink.opacity(0.25))
            }
            .padding(.vertical, 11)
            if !isLast {
                Rectangle().fill(ink.opacity(0.08)).frame(height: 0.5)
            }
        }
    }

    private var replayCard: some View {
        Button { showOnboardingReplay = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color(hex: 0x3D6A8F))
                    Image(systemName: "play.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .padding(.leading, 2)
                }
                .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Replay the intro course")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x1B3A54))
                    Text("\(fallacies.filter(\.inOnboardingCarousel).count) myths · about 2 minutes")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color(hex: 0x1B3A54).opacity(0.6))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(Color(hex: 0x3D6A8F).opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.top, 22)
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

/// One of the four "Big Four" cover cards — a curated subset (not all 20
/// fallacies), matching real slugs in the `fallacies` table. Gradient pairs,
/// ball glyphs, ink tones and shadow opacities are design-spec values from
/// the "learn-tab-8b" handoff, not derived from anything in the data model.
private struct BigFourCard: Identifiable {
    let id: String // matches Fallacy.slug
    let gradientTop: Color
    let gradientBottom: Color
    let ballGlyph: String
    let ink: Color
    let shadowOpacity: Double
    let title: String
    let verdict: String
}

private let bigFourCards: [BigFourCard] = [
    BigFourCard(id: "hot-numbers-win-more", gradientTop: Color(hex: 0x8B7CF6), gradientBottom: Color(hex: 0x5544C4),
                ballGlyph: "8", ink: Color(hex: 0x4A3BB8), shadowOpacity: 0.25,
                title: "Hot numbers", verdict: "Balls have no memory"),
    BigFourCard(id: "cold-numbers-are-due", gradientTop: Color(hex: 0x5E7CE2), gradientBottom: Color(hex: 0x2C4699),
                ballGlyph: "13", ink: Color(hex: 0x2C4699), shadowOpacity: 0.25,
                title: "Overdue numbers", verdict: "Nothing is ever due"),
    BigFourCard(id: "birthday-numbers", gradientTop: Color(hex: 0x2FBDB3), gradientBottom: Color(hex: 0x12726B),
                ballGlyph: "31", ink: Color(hex: 0x12726B), shadowOpacity: 0.22,
                title: "Birthday picks", verdict: "Same odds, smaller cut"),
    BigFourCard(id: "more-tickets-doesnt-help", gradientTop: Color(hex: 0xE6A23C), gradientBottom: Color(hex: 0xA5650C),
                ballGlyph: "$", ink: Color(hex: 0x8A5A0B), shadowOpacity: 0.22,
                title: "Buying more lines", verdict: "Losses scale too"),
]

/// One row in the "Collections" list — pushes to a small filtered list of
/// that category's 2 curated myths (see collectionSlugs below).
private struct LearnCollection: Hashable {
    let categoryKey: String
    let title: String
    let meta: String
}

private let collections: [LearnCollection] = [
    LearnCollection(categoryKey: "randomness", title: "Which numbers are due", meta: "2 busts · 3 min"),
    LearnCollection(categoryKey: "picking", title: "Picking smarter numbers", meta: "2 busts · 3 min"),
    LearnCollection(categoryKey: "money", title: "Spending your way to odds", meta: "2 busts · 4 min"),
    LearnCollection(categoryKey: "mind", title: "Is a fair game a good bet", meta: "2 busts · 3 min"),
]

/// Which 2 of each category's real fallacies are surfaced here — a curated
/// subset (8 of the 20 rows in the table), matching the "Eight beliefs"
/// framing in the title deck line. The other 12 aren't reachable from this
/// screen in this v1. randomness/picking/money's first pick matches a Big
/// Four card; the rest are the next-lowest display_order in that category.
/// This selection wasn't specified by the design handoff — flagged back
/// rather than silently finalized.
private let collectionSlugs: [String: [String]] = [
    "randomness": ["hot-numbers-win-more", "cold-numbers-are-due"],
    "picking": ["birthday-numbers", "balanced-numbers-look-more-random"],
    "money": ["more-tickets-doesnt-help", "anchoring-on-jackpot-headline"],
    "mind": ["the-system-is-rigged", "someone-always-wins"],
]

/// The small list a "Collections" row pushes to — just that category's 2
/// curated myths, reusing the existing Fallacy.self navigationDestination
/// declared on the root NavigationStack.
private struct CollectionListView: View {
    let title: String
    let fallacies: [Fallacy]

    var body: some View {
        List(fallacies) { fallacy in
            NavigationLink(value: fallacy) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(fallacy.mythStatement)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)
                    Text(fallacy.verdictLabel)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Color(hex: 0x1A7F37))
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Opens a single myth in the SAME light, Wrapped-style format as the
/// onboarding carousel: saturated background, vignette (for onboarding
/// myths), bold myth line, marker-highlighted truth, body, and stat pill.
/// Unchanged by the Learn tab list redesign above.
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

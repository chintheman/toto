import SwiftUI

/// A pushed reel visit: which category (for the breadcrumb) and the
/// number sequence to swipe through. Building one via `.shuffled` or
/// `.sequential` re-randomizes (or re-derives) the sequence fresh, so
/// pushing the same category twice never replays the same order.
struct ReelDestination: Hashable {
    let category: NumberCategory
    let sequence: [Int]
    let startIndex: Int

    /// Category tiles and the hero card use this: a freshly shuffled order
    /// with `startingAt` moved to the front, so tapping "17" on the hero
    /// card actually opens on 17 rather than wherever it lands in the
    /// shuffle.
    static func shuffled(category: NumberCategory, startingAt startingNumber: Int) -> ReelDestination {
        var rest = category.numbers.filter { $0 != startingNumber }
        rest.shuffle()
        return ReelDestination(category: category, sequence: [startingNumber] + rest, startIndex: 0)
    }

    /// The All Numbers grid jumps straight to a specific number in its
    /// natural 1...49 order, no shuffling.
    static func sequential(startingAt startingNumber: Int) -> ReelDestination {
        let sequence = Array(1...49)
        let index = sequence.firstIndex(of: startingNumber) ?? 0
        return ReelDestination(category: .allNumbers, sequence: sequence, startIndex: index)
    }
}

/// Full-bleed, one-number-at-a-time browsing screen (Instagram-Reels
/// style), pushed from the Numbers hub or the All Numbers grid. Horizontal
/// swipe moves within the current category; vertical swipe switches to the
/// adjacent category (order = `NumberCategory.allCases`), reshuffling that
/// category's sequence fresh. A persistent breadcrumb + progress bar +
/// edge-peek category hints keep the user oriented, since neither axis of
/// this two-axis swipe is discoverable on its own.
struct NumberReelView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var category: NumberCategory
    @State private var sequence: [Int]
    @State private var currentIndex: Int
    @State private var factsByNumber: [Int: NumberFact] = [:]
    @State private var loadFailed = false
    // Expandable "see the numbers" panel (kept from the pre-redesign
    // NumberDetailView, whose plain-list screen this reel otherwise
    // replaces) — loaded lazily per number, only once its panel is opened,
    // rather than fetching stats for the whole sequence up front.
    @State private var expandedNumbers: Set<Int> = []
    @State private var statsByNumber: [Int: NumberStats] = [:]
    @State private var statsLoading: Set<Int> = []
    @State private var statsFailed: Set<Int> = []
    private let factsRepository: FactsRepository
    private let drawsRepository: DrawsRepository

    init(
        destination: ReelDestination,
        factsRepository: FactsRepository = FactsRepository(),
        drawsRepository: DrawsRepository = DrawsRepository()
    ) {
        _category = State(initialValue: destination.category)
        _sequence = State(initialValue: destination.sequence)
        _currentIndex = State(initialValue: destination.startIndex)
        self.factsRepository = factsRepository
        self.drawsRepository = drawsRepository
    }

    private static let categoryCycle = NumberCategory.allCases

    private var previousCategory: NumberCategory {
        let order = Self.categoryCycle
        let index = order.firstIndex(of: category) ?? 0
        return order[(index - 1 + order.count) % order.count]
    }

    private var nextCategory: NumberCategory {
        let order = Self.categoryCycle
        let index = order.firstIndex(of: category) ?? 0
        return order[(index + 1) % order.count]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x3AC1DB), Color(hex: 0x1B6E85)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Text("▲ \(previousCategory.breadcrumbTitle)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 10)

                TabView(selection: $currentIndex) {
                    ForEach(Array(sequence.enumerated()), id: \.offset) { index, number in
                        numberPage(number).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                Text("▼ \(nextCategory.breadcrumbTitle)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient(colors: [.clear, .black.opacity(0.32)], startPoint: .top, endPoint: .bottom))
                    .padding(.bottom, 90)
            }
        }
        .navBarAppearance(.dark)
        .toolbar(.hidden, for: .navigationBar)
        // simultaneousGesture, not gesture: a plain .gesture() on this
        // ancestor view would win priority over the TabView's own pan
        // recognizer below and swallow horizontal swipes entirely. This
        // way both run concurrently — the TabView still pages normally,
        // and this only acts on its own onEnded when the drag turns out
        // to have been mostly vertical.
        .simultaneousGesture(verticalCategoryGesture)
        .task(id: category) { await loadFacts() }
        // Registered here rather than relying on a parent NavigationStack
        // to already have it — the reel can be pushed from Home, the
        // Numbers hub, or the All Numbers grid, and only Home happens to
        // register a Draw destination of its own. The "last seen in Draw
        // #N" stats insight needs this to work from every entry point.
        .navigationDestination(for: Draw.self) { draw in
            DrawDetailView(draw: draw)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 3) {
                ForEach(sequence.indices, id: \.self) { index in
                    Capsule()
                        .fill(.white.opacity(index <= currentIndex ? 0.95 : 0.28))
                        .frame(height: 3)
                }
            }
            HStack(spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text(category.breadcrumbTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(currentIndex + 1) of \(sequence.count)")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // A ScrollView + minHeight-to-container-height keeps the page centered
    // like a fixed layout when short (the common case), but lets it
    // actually scroll instead of clipping once the stats panel below is
    // expanded and the content no longer fits one screen.
    private func numberPage(_ number: Int) -> some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 18) {
                    ZStack {
                        Circle().fill(.white.opacity(0.18))
                        Text("\(number)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 96, height: 96)

                    if let fact = factsByNumber[number] {
                        Text(fact.headline)
                            .font(.system(size: 24, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                        Text(fact.body)
                            .font(.system(size: 16))
                            .lineSpacing(3)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.85))
                    } else if loadFailed {
                        Text("Couldn't load this number's story")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                        Button("Retry") { Task { await loadFacts() } }
                            .buttonStyle(.borderedProminent)
                    } else {
                        ProgressView().tint(.white)
                    }

                    Text("‹ swipe for more \(category.breadcrumbTitle) ›")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))

                    statsDisclosure(for: number)
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 40)
                .frame(minHeight: geo.size.height, alignment: .center)
            }
        }
    }

    private func statsDisclosure(for number: Int) -> some View {
        let isExpanded = expandedNumbers.contains(number)
        return VStack(spacing: 12) {
            Button {
                toggleStats(for: number)
            } label: {
                HStack(spacing: 6) {
                    Text(isExpanded ? "Hide the numbers" : "See the numbers")
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            }

            if isExpanded {
                if let stats = statsByNumber[number] {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(stats.insights()) { insight in
                            let row = HStack(alignment: .top, spacing: 8) {
                                Image(systemName: insight.symbol)
                                    .frame(width: 18)
                                    .foregroundStyle(.white.opacity(0.85))
                                Text(insight.text)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            if let draw = insight.linkedDraw {
                                NavigationLink(value: draw) { row }
                            } else {
                                row
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                } else if statsFailed.contains(number) {
                    VStack(spacing: 8) {
                        Text("Couldn't load this number's stats")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.85))
                        Button("Retry") { loadStatsIfNeeded(for: number) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                } else {
                    ProgressView().tint(.white)
                }
            }
        }
    }

    /// Only a mostly-vertical drag switches category — this runs alongside
    /// the horizontal page TabView, so a shallow or diagonal drag must fall
    /// through to it rather than get eaten here.
    private var verticalCategoryGesture: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                switchCategory(to: value.translation.height < 0 ? nextCategory : previousCategory)
            }
    }

    private func switchCategory(to newCategory: NumberCategory) {
        category = newCategory
        if newCategory == .allNumbers {
            sequence = Array(1...49)
            currentIndex = 0
        } else {
            var shuffled = newCategory.numbers
            shuffled.shuffle()
            sequence = shuffled
            currentIndex = 0
        }
        factsByNumber = [:]
        loadFailed = false
    }

    private func loadFacts() async {
        loadFailed = false
        do {
            let grouped = try await factsRepository.topFacts(forNumbers: sequence, limitPerNumber: 5)
            // "which fact shows is re-randomised every visit" — pick
            // randomly among each number's available facts rather than
            // always showing the same top-priority one.
            factsByNumber = grouped.compactMapValues { $0.randomElement() }
        } catch {
            loadFailed = true
        }
    }

    private func toggleStats(for number: Int) {
        if expandedNumbers.contains(number) {
            expandedNumbers.remove(number)
        } else {
            expandedNumbers.insert(number)
            loadStatsIfNeeded(for: number)
        }
    }

    /// Cached per number for the rest of this reel session — swiping back
    /// to a number already looked at doesn't re-fetch.
    private func loadStatsIfNeeded(for number: Int) {
        guard statsByNumber[number] == nil, !statsLoading.contains(number) else { return }
        statsLoading.insert(number)
        statsFailed.remove(number)
        Task {
            do {
                async let appearances = drawsRepository.allAppearances(ofNumber: number)
                async let total = drawsRepository.totalDrawCount()
                async let latest = drawsRepository.latestDraw()
                statsByNumber[number] = NumberStats.build(
                    appearances: try await appearances,
                    total: try await total,
                    latest: (try await latest)?.drawNumber
                )
            } catch {
                statsFailed.insert(number)
            }
            statsLoading.remove(number)
        }
    }
}

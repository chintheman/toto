import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if viewModel.errorMessage != nil {
                        refreshFailedBanner
                    }
                    nextDrawCard
                    if let draw = viewModel.latestDraw {
                        NavigationLink(value: draw) {
                            latestResultCard(draw)
                        }
                        .buttonStyle(.plain)
                        curatedFactsSection(for: draw)
                    }
                }
                .padding()
            }
            .refreshable { await viewModel.load() }
            .navigationTitle("TOTO")
            .navigationDestination(for: Draw.self) { draw in
                DrawDetailView(draw: draw)
            }
            .navigationDestination(for: Int.self) { number in
                NumberDetailView(number: number)
            }
            .task { await viewModel.load() }
            .overlay {
                if viewModel.isLoading && viewModel.latestDraw == nil {
                    ProgressView()
                }
            }
        }
    }

    /// Design-changes §2: amber banner with Retry instead of a blank
    /// screen. Cached content stays visible underneath.
    private var refreshFailedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text(staleDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Retry") {
                Task { await viewModel.load() }
            }
            .font(.footnote.bold())
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .controlSize(.small)
        }
        .padding(12)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private var staleDescription: String {
        if let fetchedAt = viewModel.lastFetchedAt {
            let age = RelativeDateTimeFormatter().localizedString(for: fetchedAt, relativeTo: Date())
            return "Couldn't refresh. Showing results from \(age)."
        }
        return "Couldn't load draw data. Check your connection."
    }

    private var cachedPill: some View {
        Group {
            if let fetchedAt = viewModel.lastFetchedAt, viewModel.errorMessage != nil {
                Text("cached \(RelativeDateTimeFormatter().localizedString(for: fetchedAt, relativeTo: Date()))")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var nextDrawCard: some View {
        // The jackpot amount is the headline number here, not the date — a
        // draw date on its own tells you nothing about whether to care.
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Next Draw", systemImage: "calendar")
                    .sectionHeaderStyle()
                Spacer()
                cachedPill
            }

            if let upcoming = viewModel.upcomingDraw {
                Text(upcoming.drawDate, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let jackpot = upcoming.estimatedJackpot {
                    Text("Estimated jackpot")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(jackpot, format: .currency(code: "SGD").precision(.fractionLength(0)))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                } else {
                    Text("Estimated jackpot not published yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if upcoming.isSnowball {
                    Text("Snowball draw").font(.caption.bold()).foregroundStyle(.orange)
                }
            } else {
                Text(viewModel.localNextDrawEstimate, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Jackpot amount unavailable. Showing estimated schedule only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func latestResultCard(_ draw: Draw) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Latest Result · Draw #\(draw.drawNumber, format: .number.grouping(.never))", systemImage: "checkmark.seal")
                    .sectionHeaderStyle()
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.bold())
                    .foregroundStyle(.tertiary)
            }
            Text(draw.drawDate, style: .date)
                .font(.subheadline)

            HStack(spacing: 8) {
                ForEach(draw.winningNumbers, id: \.self) { number in
                    LotteryBallView(number: number, size: 40)
                }
                Text("+")
                    .foregroundStyle(.secondary)
                LotteryBallView(number: draw.additionalNumber, size: 40, isAdditional: true)
            }

            // §2: make it unambiguous whether the amount was won or rolled over.
            if draw.jackpotWon {
                Label {
                    Text("A player won the \(draw.jackpotAmount, format: .currency(code: "SGD").precision(.fractionLength(0))) jackpot.")
                        .font(.subheadline.bold())
                } icon: {
                    Image(systemName: "trophy.fill")
                }
                .foregroundStyle(.green)
            } else {
                Label {
                    Text("No winner. The \(draw.jackpotAmount, format: .currency(code: "SGD").precision(.fractionLength(0))) jackpot rolled over to the next draw.")
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "arrow.uturn.forward")
                }
                .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func curatedFactsSection(for draw: Draw) -> some View {
        let picks = pickDiverseFacts(
            numbers: draw.winningNumbers + [draw.additionalNumber],
            factsByNumber: viewModel.curatedFacts,
            limit: 2
        )
        return VStack(alignment: .leading, spacing: 14) {
            Label("Fun Facts About These Numbers", systemImage: "sparkles")
                .sectionHeaderStyle()

            ForEach(picks.indices, id: \.self) { index in
                let (number, fact) = picks[index]
                if index > 0 { Divider() }
                // Each fact pushes straight to that number's own page —
                // previously this whole section was read-only.
                NavigationLink(value: number) {
                    HStack(alignment: .top, spacing: 12) {
                        LotteryBallView(number: number, size: 36)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(fact.headline)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(fact.body)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.bold())
                            .foregroundStyle(.tertiary)
                            .padding(.top, 3)
                    }
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Opens number \(number)'s page")
                }
                .buttonStyle(.plain)
            }

            Divider()
            Text("Tap a fact above for the full story, or browse all 49 numbers in History → Numbers.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

/// Picks one fact per number for the Home preview, preferring a category
/// that isn't already used by an earlier pick. Two facts of the exact same
/// shape (e.g. both "appeared N times in Y draws, vs Z expected") read as
/// duplicates even though the numbers differ, which defeats the point of a
/// varied fun-facts preview. Falls back to a number's top-priority fact if
/// none of its candidates offer an unused category, rather than showing
/// nothing for that number.
private func pickDiverseFacts(
    numbers: [Int],
    factsByNumber: [Int: [NumberFact]],
    limit: Int
) -> [(number: Int, fact: NumberFact)] {
    var chosen: [(number: Int, fact: NumberFact)] = []
    var usedCategories: Set<NumberFact.Category> = []

    for number in numbers {
        guard chosen.count < limit,
              let candidates = factsByNumber[number], !candidates.isEmpty else { continue }
        let pick = candidates.first { !usedCategories.contains($0.category) } ?? candidates[0]
        chosen.append((number, pick))
        usedCategories.insert(pick.category)
    }
    return chosen
}

#Preview {
    HomeView()
}

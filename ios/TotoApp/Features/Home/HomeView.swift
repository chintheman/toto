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
                        latestResultCard(draw)
                        curatedFactsSection(for: draw)
                    }
                }
                .padding()
            }
            .refreshable { await viewModel.load() }
            .navigationTitle("TOTO")
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Next Draw", systemImage: "calendar")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                cachedPill
            }

            if let upcoming = viewModel.upcomingDraw {
                Text(upcoming.drawDate, style: .date)
                    .font(.title2.bold())
                if let jackpot = upcoming.estimatedJackpot {
                    Text("Estimated jackpot: \(jackpot, format: .currency(code: "SGD"))")
                        .font(.subheadline)
                } else {
                    Text("Estimated jackpot not published yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if upcoming.isSnowball {
                    Text("Snowball draw").font(.caption).foregroundStyle(.orange)
                }
            } else {
                Text(viewModel.localNextDrawEstimate, style: .date)
                    .font(.title2.bold())
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
            Label("Latest Result · Draw #\(draw.drawNumber)", systemImage: "checkmark.seal")
                .font(.headline)
                .foregroundStyle(.secondary)
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

            // §2: the draw's jackpot amount is shown alongside its outcome.
            HStack {
                Text("Jackpot: \(draw.jackpotAmount, format: .currency(code: "SGD").precision(.fractionLength(0)))")
                    .font(.subheadline)
                Spacer()
                if draw.jackpotWon {
                    Text("Won by a player").font(.subheadline.bold()).foregroundStyle(.green)
                } else {
                    Text("Rolled over").font(.subheadline).foregroundStyle(.orange)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func curatedFactsSection(for draw: Draw) -> some View {
        // Show at most two facts, drawn from the winning numbers in order.
        let factNumbers = (draw.winningNumbers + [draw.additionalNumber])
            .filter { viewModel.curatedFacts[$0]?.first != nil }
            .prefix(2)
        return VStack(alignment: .leading, spacing: 12) {
            Label("Fun Facts About These Numbers", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(Array(factNumbers), id: \.self) { number in
                if let fact = viewModel.curatedFacts[number]?.first {
                    HStack(alignment: .top, spacing: 12) {
                        LotteryBallView(number: number, size: 32)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(fact.headline).font(.subheadline.bold())
                            Text(fact.body).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Divider()
            Text("Every number has a story. Tap any ball in History → Numbers for more.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

#Preview {
    HomeView()
}

import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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

    private var nextDrawCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Next Draw", systemImage: "calendar")
                .font(.headline)
                .foregroundStyle(.secondary)

            if let upcoming = viewModel.upcomingDraw {
                Text(upcoming.drawDate, style: .date)
                    .font(.title2.bold())
                Text("Estimated jackpot: \(upcoming.estimatedJackpot, format: .currency(code: "SGD"))")
                    .font(.subheadline)
                if upcoming.isSnowball {
                    Text("Snowball draw").font(.caption).foregroundStyle(.orange)
                }
            } else {
                Text(viewModel.localNextDrawEstimate, style: .date)
                    .font(.title2.bold())
                Text("Jackpot amount unavailable — showing estimated schedule only")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func latestResultCard(_ draw: Draw) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Latest Result — Draw #\(draw.drawNumber)", systemImage: "checkmark.seal")
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

            if draw.jackpotWon {
                Text("Jackpot won this draw!").font(.subheadline.bold()).foregroundStyle(.green)
            } else {
                Text("Jackpot rolled over").font(.subheadline).foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func curatedFactsSection(for draw: Draw) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Fun Facts About Today's Numbers", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(draw.winningNumbers + [draw.additionalNumber], id: \.self) { number in
                if let facts = viewModel.curatedFacts[number], let fact = facts.first {
                    HStack(alignment: .top, spacing: 12) {
                        LotteryBallView(number: number, size: 32)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(fact.headline).font(.subheadline.bold())
                            Text(fact.body).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

#Preview {
    HomeView()
}

import SwiftUI

struct CalculatorView: View {
    @State private var viewModel = CalculatorViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    budgetInput
                    if let jackpot = viewModel.currentJackpot {
                        evStatusCard(jackpot: jackpot)
                        strategyCard
                        oddsBreakdownCard
                    } else if !viewModel.isLoading {
                        ContentUnavailableView(
                            "No jackpot data yet",
                            systemImage: "questionmark.circle",
                            description: Text("The upcoming draw's jackpot hasn't been scraped yet.")
                        )
                    }
                    disclaimer
                }
                .padding()
            }
            .navigationTitle("Calculator")
            .task { await viewModel.load() }
            .overlay {
                if viewModel.isLoading { ProgressView() }
            }
        }
    }

    private var budgetInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your budget").font(.headline)
            HStack {
                Text(viewModel.budget, format: .currency(code: "SGD"))
                    .font(.title2.bold())
                Spacer()
                Stepper("", value: $viewModel.budget, in: 1...1000, step: 7)
                    .labelsHidden()
            }
        }
        .cardStyle()
    }

    private func evStatusCard(jackpot: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: viewModel.isPositiveEV ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                    .foregroundStyle(viewModel.isPositiveEV ? Theme.positiveEV : Theme.negativeEV)
                Text(viewModel.isPositiveEV ? "+EV territory" : "-EV territory")
                    .font(.headline)
                    .foregroundStyle(viewModel.isPositiveEV ? Theme.positiveEV : Theme.negativeEV)
            }

            if let ev = viewModel.ordinaryEV {
                Text("Every $1 spent returns about \(ev, format: .currency(code: "SGD").precision(.fractionLength(2))) on average at the current \(jackpot, format: .currency(code: "SGD")) jackpot.")
                    .font(.subheadline)
            }

            if !viewModel.isPositiveEV, let gap = viewModel.jackpotGapToBreakEven, gap > 0 {
                Text("The jackpot would need to grow by about \(gap, format: .currency(code: "SGD")) (to roughly \(viewModel.breakEvenJackpot, format: .currency(code: "SGD"))) to flip to +EV. Otherwise: wait for a bigger jackpot rather than spending more now.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if viewModel.isPositiveEV {
                Text("This is one of the better times to play, mathematically speaking — though still a lottery, not an investment.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var strategyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Suggested Allocation", systemImage: "chart.pie.fill")
                .font(.headline)
            Text("With \(viewModel.budget, format: .currency(code: "SGD")), spreading across \(viewModel.affordableSystem7Count) System 7 entries covers more of the 49 numbers than concentrating the same budget into fewer, bigger systems — more prize-tier hits on average for the same spend.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var oddsBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Odds by Bet Type", systemImage: "list.bullet")
                .font(.headline)
            ForEach(viewModel.oddsByBetType) { odds in
                HStack {
                    Text(odds.betType.displayName).font(.subheadline.bold())
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Any prize: 1 in \(Int(1 / max(odds.probabilityAnyPrize, .leastNormalMagnitude)))")
                        Text("Jackpot: 1 in \(Int(1 / max(odds.probabilityJackpot, .leastNormalMagnitude)))")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var disclaimer: some View {
        Text("This is a mathematical optimization tool, not gambling advice. The draw is fair and no strategy beats it — this only helps you understand the odds you're already facing. Play responsibly.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
    }
}

extension BetOdds: Identifiable {
    var id: String { betType.id }
}

#Preview {
    CalculatorView()
}

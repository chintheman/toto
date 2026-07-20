import SwiftUI

struct CalculatorView: View {
    @State private var viewModel: CalculatorViewModel

    init(budgetState: BudgetState = BudgetState()) {
        _viewModel = State(initialValue: CalculatorViewModel(budgetState: budgetState))
    }

    /// en_SG currency formatter used for the typeable TextField.
    private let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "SGD"
        f.locale = Locale(identifier: "en_SG")
        f.maximumFractionDigits = 0
        return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    budgetCard

                    if viewModel.currentJackpot != nil {
                        whatCanBuyCard
                        valueOfThisDrawCard
                    } else if !viewModel.isLoading {
                        ContentUnavailableView(
                            "No jackpot data yet",
                            systemImage: "questionmark.circle",
                            description: Text("The upcoming draw's jackpot hasn't been scraped yet.")
                        )
                    }

                    // Error state
                    if let error = viewModel.errorMessage, viewModel.currentJackpot == nil {
                        ContentUnavailableView(
                            "Couldn't load jackpot data",
                            systemImage: "wifi.slash",
                            description: Text(error)
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

    // MARK: - Card 1: Budget

    private var budgetCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your budget").font(.headline)

            Text(viewModel.budgetState.budget, format: .currency(code: "SGD").precision(.fractionLength(0)))
                .font(.title2.bold())

            Slider(value: Bindable(viewModel.budgetState).budget, in: 1...100_000, step: 1)

            HStack {
                Text("Amount")
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("1 – 100,000", value: Bindable(viewModel.budgetState).budget, formatter: currencyFormatter)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 160)
            }
            .font(.subheadline)
        }
        .cardStyle()
    }

    // MARK: - Card 2: What $X can buy

    private var whatCanBuyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What \(budgetFormatted) can buy")
                .font(.headline)

            ForEach(viewModel.affordableEntries, id: \.betType.id) { entry in
                affordableRow(for: entry)
            }

            Text("Same expected return either way — spending pattern only changes how the losses arrive, never their average size.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .cardStyle()
    }

    private func affordableRow(for entry: (betType: BetType, count: Int, cost: Double)) -> some View {
        let budget = viewModel.budgetState.budget
        return HStack {
            HStack(spacing: 3) {
                Text(entry.count.formatted(.number))
                    .monospacedDigit()
                Text("\u{00D7}")
                Text(entry.betType.displayName)
            }
            Spacer()
            Text("\(entry.cost.formatted(.currency(code: "SGD").precision(.fractionLength(0)))) of \(budget.formatted(.currency(code: "SGD").precision(.fractionLength(0))))")
                .monospacedDigit()
        }
        .font(.subheadline)
    }

    // MARK: - Card 3: Value of this draw

    private var valueOfThisDrawCard: some View {
        Group {
            if let ev = viewModel.ordinaryEV, let jackpot = viewModel.currentJackpot {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Value of this draw").font(.headline)

                    Text("About \(evString(ev)) back per $1, on average")
                        .font(.title3.bold())

                    EVGaugeView(ev: ev)

                    Text("At the current \(jackpot.formatted(.currency(code: "SGD").precision(.fractionLength(0)))) jackpot. This rate depends only on the jackpot size — spending more doesn't change it, every dollar gets the same ~58\u{00A2} back. Break-even needs roughly a \(viewModel.breakEvenJackpot.formatted(.currency(code: "SGD").precision(.fractionLength(0)))) jackpot, but big jackpots attract more players and get split more often — so in practice, break-even draws don't really exist.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .cardStyle()
            }
        }
    }

    /// Formats a per-dollar EV figure like 0.58 → "58¢".
    private func evString(_ ev: Double) -> String {
        let cents = Int((ev * 100).rounded())
        return "\(cents)\u{00A2}"
    }

    // MARK: - Card 4: Disclaimer

    private var disclaimer: some View {
        Text("This is an odds explainer, not gambling advice. No strategy beats the draw. Play responsibly.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
    }

    // MARK: - Helpers

    private var budgetFormatted: String {
        viewModel.budgetState.budget.formatted(.currency(code: "SGD").precision(.fractionLength(0)))
    }
}

// MARK: - EV Gauge

private struct EVGaugeView: View {
    let ev: Double

    /// Maps EV to a 0-1 position.  0 EV → 0%,  1.0 EV → ~83%,  ≥1.2 → 100%.
    private var fractionalPosition: CGFloat {
        min(1.0, max(0, ev / 1.2))
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let position = width * fractionalPosition

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(
                        colors: [.red, .orange, .green],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(height: 8)

                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .shadow(color: .black.opacity(0.2), radius: 3)
                    .offset(x: position - 8)
            }
        }
        .frame(height: 24)
    }
}

#Preview {
    CalculatorView()
}

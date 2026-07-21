import SwiftUI

/// Design-changes §4 redesign. Card order: Budget → What $X can buy →
/// Value of this draw → disclaimer. The budget is app-wide state shared
/// live with Picks. No draw is ever framed as "+EV / good time to play".
struct CalculatorView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = CalculatorViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                    }
                    BudgetCard()
                    affordabilityCard
                    if let jackpot = viewModel.currentJackpot {
                        valueCard(jackpot: jackpot)
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
                if viewModel.isLoading && viewModel.currentJackpot == nil { ProgressView() }
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
            Text("Couldn't refresh jackpot data.").font(.footnote).foregroundStyle(.secondary)
            Spacer()
            Button("Retry") { Task { await viewModel.load() } }
                .font(.footnote.bold())
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.small)
        }
        .padding(12)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private var affordabilityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What SGD \(appState.budget.formatted()) can buy")
                .font(.headline)
            Text("Every combination below costs the same per line of coverage. Spreading means smaller prizes land more often; concentrating means rarer but larger hits. Average return is identical either way.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(viewModel.affordableCombos(budget: appState.budget)) { combo in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(combo.count.formatted())×")
                        .font(.body.bold().monospacedDigit())
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: 76, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(combo.betType.displayName).font(.subheadline.bold())
                        Text(combo.betType.coverageDescription).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("$\(combo.spend.formatted()) of $\(appState.budget.formatted())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                .padding(10)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            }

            Text("Same expected return either way. Spending pattern only changes how the losses arrive, never their average size.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func valueCard(jackpot: Double) -> some View {
        let ev = viewModel.ordinaryEV ?? 0
        let cents = Int((ev * 100).rounded())
        return VStack(alignment: .leading, spacing: 12) {
            Text("Value of this draw").font(.headline)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(
                            colors: [.red.opacity(0.85), .orange.opacity(0.85), .green.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(height: 10)
                    Circle()
                        .fill(.background)
                        .stroke(.primary, lineWidth: 3)
                        .frame(width: 20, height: 20)
                        .offset(x: (proxy.size.width - 20) * viewModel.gaugeFraction)
                }
            }
            .frame(height: 20)

            HStack {
                Text("POOR VALUE")
                Spacer()
                Text("BREAK-EVEN")
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)

            Text("About \(cents)¢ back per $1, on average")
                .font(.subheadline.bold())

            Text("At the current \(jackpot, format: .currency(code: "SGD").precision(.fractionLength(0))) jackpot. This rate depends only on the jackpot size. Spending more doesn't change it; every dollar gets the same ~\(cents)¢ back. Breaking even needs roughly a \(viewModel.breakEvenJackpot, format: .currency(code: "SGD").precision(.fractionLength(0))) jackpot, but big jackpots attract more players and get split more often, so in practice those draws don't really exist.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var disclaimer: some View {
        Text("This is an odds explainer, not gambling advice. No strategy beats the draw. Play responsibly.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
    }
}

/// Shared budget input (design-changes §4/§5): typeable amount + slider,
/// $1–$100,000, en-SG thousands formatting, one app-wide source of truth.
struct BudgetCard: View {
    @Environment(AppState.self) private var appState
    var showsSyncedPill = false

    var body: some View {
        @Bindable var appState = appState
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Your budget").font(.headline)
                Spacer()
                if showsSyncedPill {
                    Text("synced with Calculator")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: Capsule())
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("SGD").font(.title2.bold())
                TextField("Budget", value: $appState.budget, format: .number)
                    .keyboardType(.numberPad)
                    .font(.title2.bold())
                    .foregroundStyle(.tint)
            }

            Slider(
                value: Binding(
                    get: { Double(appState.budget) },
                    set: { appState.budget = Int($0) }
                ),
                in: Double(AppState.budgetRange.lowerBound)...Double(AppState.budgetRange.upperBound),
                step: 1
            )

            HStack {
                Text("$1")
                Spacer()
                Text("$100,000")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

#Preview {
    CalculatorView()
        .environment(AppState())
}

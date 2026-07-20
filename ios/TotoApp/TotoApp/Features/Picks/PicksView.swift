import SwiftUI

struct PicksView: View {
    @State private var viewModel: PicksViewModel
    @State private var localEditingBudget: String = ""

    init(budgetState: BudgetState = BudgetState()) {
        _viewModel = State(initialValue: PicksViewModel(budgetState: budgetState))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sharedBudgetSection
                    syncedPill
                    goalCardsSection
                    if viewModel.selectedGoal == .jackpot {
                        jackpotRecommendationCard
                    } else {
                        targetRecommendationCard
                    }
                    premiumTeaserSection
                    disclaimer
                }
                .padding()
            }
            .navigationTitle("Picks")
            .task { await viewModel.load() }
            .overlay {
                if viewModel.isLoading { ProgressView() }
            }
            .onChange(of: viewModel.budgetState.budget) { _, _ in
                localEditingBudget = ""
            }
        }
    }

    // MARK: – Shared budget section

    private var sharedBudgetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your budget").font(.headline)

            HStack {
                Text(viewModel.budgetState.budget, format: .currency(code: "SGD"))
                    .font(.title2.bold())
                Spacer()
                Stepper("", value: Bindable(viewModel.budgetState).budget, in: 1...1000, step: 7)
                    .labelsHidden()
            }

            Slider(value: Bindable(viewModel.budgetState).budget, in: 1...1000, step: 1)
                .tint(Color.accentColor)

            HStack {
                Text("$1")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("$1,000")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    // MARK: – Synced pill badge

    private var syncedPill: some View {
        HStack {
            Image(systemName: "link.circle.fill")
                .foregroundStyle(.blue)
            Text("Synced with Calculator")
                .font(.caption)
                .foregroundStyle(.blue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.blue.opacity(0.1), in: Capsule())
        .frame(maxWidth: .infinity)
    }

    // MARK: – Goal radio cards

    private var goalCardsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your goal").font(.headline)

            ForEach(PicksGoal.allCases) { goal in
                let isSelected = viewModel.selectedGoal == goal
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedGoal = goal
                    }
                } label: {
                    HStack(spacing: 12) {
                        radioIcon(isSelected: isSelected)
                        goalIcon(goal: goal)
                        goalText(goal: goal)
                        Spacer()
                    }
                    .padding(12)
                    .background(
                        isSelected
                            ? Color.accentColor.opacity(0.08)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                            .stroke(
                                isSelected
                                    ? Color.accentColor.opacity(0.4)
                                    : Color.clear,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .cardStyle()
    }

    private func radioIcon(isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "circle.fill" : "circle")
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .font(.title3)
    }

    private func goalIcon(goal: PicksGoal) -> some View {
        Image(systemName: goal.systemImage)
            .foregroundStyle(Color.accentColor)
            .font(.title3)
    }

    private func goalText(goal: PicksGoal) -> some View {
        Text(goal.displayTitle)
            .font(.subheadline.bold())
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
    }

    // MARK: – Recommended play cards

    private var jackpotRecommendationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Recommended Play", systemImage: "star.fill")
                .font(.headline)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Play:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.jackpotResult.lines) × Ordinary")
                        .font(.subheadline.bold())
                }

                HStack {
                    Text("Total spend:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("$\(viewModel.jackpotResult.lines)")
                        .font(.subheadline.bold())
                }

                HStack(alignment: .top) {
                    Text("Odds:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("1 in \(viewModel.jackpotResult.oddsDenominator)")
                        .font(.subheadline.bold())
                }
            }

            Divider()

            Text(viewModel.jackpotResult.explanation)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var targetRecommendationCard: some View {
        Group {
            if let result = viewModel.targetResult {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Recommended Play", systemImage: "star.fill")
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Play:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("\(result.entries) × \(result.bestBet.displayName)")
                                .font(.subheadline.bold())
                        }

                        if result.bestBet.cost > 0 {
                            HStack {
                                Text("Unit cost:")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("$\(Int(result.bestBet.cost))")
                                    .font(.subheadline.bold())
                            }
                        }

                        HStack(alignment: .top) {
                            Text("Target:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("≥ $\(Int(result.target))")
                                .font(.subheadline.bold())
                                .foregroundStyle(.green)
                        }

                        if result.oddsDenominator < Int.max {
                            HStack(alignment: .top) {
                                Text("Odds:")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("~1 in \(result.oddsDenominator) (estimate)")
                                    .font(.subheadline.bold())
                            }
                        }
                    }

                    Divider()

                    Text(result.explanation)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .cardStyle()
            }
        }
    }

    // MARK: – Premium teaser with email capture

    private var premiumTeaserSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Premium — Coming Soon", systemImage: "crown.fill")
                .font(.headline)
                .foregroundStyle(.yellow)

            Text("More detailed, customised combinations are coming in a future premium version. Leave your email for 50% off at launch.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if viewModel.emailSaved {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("✓ Saved")
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                }
            } else {
                HStack(spacing: 8) {
                    TextField("Your email", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))

                    Button("Notify me") {
                        withAnimation {
                            viewModel.saveEmail()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.subheadline)
                    .disabled(viewModel.email.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .cardStyle()
    }

    // MARK: – Disclaimer

    private var disclaimer: some View {
        Text("Every combination is equally likely to be drawn. These picks optimise structure, not luck. Play responsibly.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }
}

#Preview {
    PicksView()
}

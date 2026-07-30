import SwiftUI

/// Design-changes §4 redesign. Card order: Budget → What $X can buy →
/// Value of this draw → disclaimer. The budget is app-wide state shared
/// live with Picks. No draw is ever framed as "+EV / good time to play".
struct CalculatorView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = CalculatorViewModel()
    // Ordinary isn't a toggle: spendBreakdown only ever branches on
    // systemOn (the waterfall mops the remainder via Ordinary regardless
    // of any Ordinary-chip state), so an "Ordinary off" state never did
    // anything — it's locked always-on below instead of pretending to be
    // an interactive toggle that silently no-ops.
    @State private var systemOn = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                    }
                    BudgetCard()
                    strategiesLockToggle
                    affordabilityCard
                    if viewModel.currentJackpot != nil {
                        valueCard
                    } else if !viewModel.isLoading && viewModel.errorMessage == nil {
                        // Only the "no data yet" state when there's no error;
                        // otherwise the error banner above already explains it.
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
            .floatingNavBarClearance()
            // Tapping or scrolling anywhere else on the page exits the
            // budget field's edit mode (see BudgetCard) — the same
            // resigned-focus path Confirm and Cancel already use.
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Budget")
            .navigationDestination(for: BetTypesDestination.self) { _ in
                BetTypesInfoView()
            }
            .task { await viewModel.load() }
            .overlay {
                if viewModel.isLoading && viewModel.currentJackpot == nil { ProgressView() }
            }
        }
    }

    private func toggleSystem() {
        systemOn.toggle()
    }

    /// Was a real Picks tab; now a locked, non-tappable placeholder living
    /// inside Budget until the goal-based Picks feature gets more design
    /// work (see PicksView.swift, kept but unreachable from navigation).
    private var strategiesLockToggle: some View {
        HStack(spacing: 4) {
            Text("Calculator")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 6) {
                Text("Strategies")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                Text("SOON")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.4)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.25), in: Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .opacity(0.5)
        }
        .padding(4)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Calculator, selected. Strategies, coming soon, unavailable.")
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
        let rows = viewModel.spendBreakdown(budget: appState.budget, systemOn: systemOn)
        let total = rows.reduce(0) { $0 + $1.combinations }

        return VStack(alignment: .leading, spacing: 12) {
            Text("What SGD \(appState.budget.formatted()) can buy")
                .font(.title2.bold())

            HStack(spacing: 4) {
                // Locked always-selected, not a real toggle — see the
                // systemOn comment above.
                Text("Ordinary")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(Color.white)
                    .accessibilityAddTraits(.isSelected)

                affordabilityToggleChip(title: "System", isOn: systemOn, action: toggleSystem)
            }
            .padding(4)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))

            if rows.count == 1, let only = rows.first {
                breakdownRow(only, isBold: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(rows) { row in
                        if row.id != rows.first?.id { Divider() }
                        breakdownRow(row, isBold: false)
                    }
                    Divider()
                    HStack {
                        Text("Total").font(.subheadline.bold())
                        Spacer()
                        Text("\(total.formatted()) combinations").font(.subheadline.bold())
                    }
                    .padding(.vertical, 4)
                }
            }

            NavigationLink(value: BetTypesDestination()) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    Text("Ordinary, System 7 to 10 explained")
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                }
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func breakdownRow(_ row: SpendBreakdownRow, isBold: Bool) -> some View {
        HStack {
            Text("\(row.count.formatted())× \(row.name)")
                .font(isBold ? .headline : .subheadline)
            Spacer()
            Text("\(row.combinations.formatted()) combinations")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func affordabilityToggleChip(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isOn ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(isOn ? Color.white : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private var valueCard: some View {
        let displayedJackpot = viewModel.displayedJackpot ?? 0
        let ev = viewModel.ordinaryEV ?? 0
        let cents = Int((ev * 100).rounded())
        let isHypothetical = viewModel.isShowingHypothetical
        return VStack(alignment: .leading, spacing: 12) {
            Text("Value of this draw").font(.title2.bold())

            jackpotChipRow

            if isHypothetical {
                // Must stay unmissable — this app has a documented history
                // of a draw once being visually implied as +EV when it
                // wasn't, and a "what if" example must never repeat that.
                Label("Example only — not tonight's actual jackpot", systemImage: "questionmark.circle.fill")
                    .font(.footnote.bold())
                    .foregroundStyle(.orange)
            }

            // Gauge size is deliberately untouched — only the surrounding
            // text grows.
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
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)

            Text("About \(cents)¢ back per $1, on average")
                .font(.title3.bold())

            // Was one long compound sentence cramming four separate ideas
            // (which jackpot, why the rate is fixed, the break-even point,
            // and why break-even is unrealistic). Splitting into a primary
            // takeaway plus a secondary caveat — same treatment as the
            // headline stat above it — gives the paragraph some hierarchy
            // instead of one dense gray block.
            VStack(alignment: .leading, spacing: 4) {
                Text("At \(isHypothetical ? "an example" : "the current") \(displayedJackpot, format: .currency(code: "SGD").precision(.fractionLength(0))) jackpot, every dollar spent returns about \(cents)¢ on average — spending more doesn't change that rate.")
                    .font(.subheadline)
                Text("Breaking even needs roughly a \(viewModel.breakEvenJackpot, format: .currency(code: "SGD").precision(.fractionLength(0))) jackpot — but jackpots that large draw more players and get split more often, so in practice they don't really happen.")
                    .font(.footnote)
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var jackpotChipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.jackpotChips()) { chip in
                    let isSelected = chip.selection == viewModel.jackpotSelection
                    Button {
                        viewModel.selectJackpot(chip.selection)
                    } label: {
                        Text(chip.label)
                            .font(.subheadline.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                            )
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var disclaimer: some View {
        Text("This is an odds explainer, not gambling advice. No strategy beats the draw. Play responsibly.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
    }
}

/// Shared budget input (design-changes §4/§5): typeable amount + slider,
/// AppState.budgetRange ($1–$500), en-SG thousands formatting, one
/// app-wide source of truth.
struct BudgetCard: View {
    @Environment(AppState.self) private var appState
    var showsSyncedPill = false

    // Typing a new budget now has an explicit edit mode: the committed
    // value (appState.budget) and the in-progress typed text (draftText)
    // are kept separate, so an X can revert the typed text without ever
    // touching the real budget, and nothing commits until the user
    // confirms, taps away, or scrolls.
    @FocusState private var isEditingBudget: Bool
    @State private var draftText: String = ""

    var body: some View {
        @Bindable var appState = appState
        VStack(alignment: .leading, spacing: 8) {
            // "Your budget" and its value used to sit on separate rows —
            // putting the value inline reclaims a full text row of height.
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Your budget").font(.title2.bold())
                Spacer()
                Text("SGD").font(.subheadline.bold()).foregroundStyle(.secondary)
                TextField("Budget", text: $draftText)
                    .keyboardType(.numberPad)
                    .font(.title2.bold())
                    .foregroundStyle(.tint)
                    .multilineTextAlignment(.trailing)
                    .fixedSize()
                    .focused($isEditingBudget)

                if isEditingBudget {
                    Button {
                        // Cancel: snap the draft back to the committed
                        // value, so whatever's typed is discarded rather
                        // than applied, then exit edit mode.
                        draftText = String(appState.budget)
                        isEditingBudget = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    Button("Confirm") {
                        isEditingBudget = false
                    }
                    .font(.subheadline.bold())
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

            if showsSyncedPill {
                HStack {
                    Spacer()
                    Text("synced with Calculator")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: Capsule())
                        .foregroundStyle(.secondary)
                }
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
                Text("$\(AppState.budgetRange.lowerBound)")
                Spacer()
                Text("$\(AppState.budgetRange.upperBound)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .onAppear {
            draftText = String(appState.budget)
        }
        .onChange(of: appState.budget) { _, newValue in
            // The slider (or the other page's shared BudgetCard) can change
            // the budget while this field isn't focused — keep the display
            // in sync, but never clobber text the user is mid-typing.
            if !isEditingBudget {
                draftText = String(newValue)
            }
        }
        .onChange(of: isEditingBudget) { wasEditing, nowEditing in
            if !wasEditing && nowEditing {
                draftText = String(appState.budget)
            } else if wasEditing && !nowEditing {
                // Editing just ended — via Confirm, Cancel, tapping away, or
                // scrolling. Cancel already reset draftText to the committed
                // value above, so this commit is a harmless no-op in that
                // case; otherwise it applies whatever was typed.
                if let value = Int(draftText) {
                    appState.budget = value
                } else {
                    draftText = String(appState.budget)
                }
            }
        }
    }
}

#Preview {
    CalculatorView()
        .environment(AppState())
}

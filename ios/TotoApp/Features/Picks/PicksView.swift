import SwiftUI
import Supabase

/// Design-changes §5: goal-based recommendations from the shared budget.
/// Language is always "Best odds…", results are labeled estimates, and the
/// disclaimer makes clear picks optimise structure, not luck.
enum PickGoal: String, CaseIterable, Identifiable {
    case jackpot, win100, win1000, double

    var id: String { rawValue }

    var title: String {
        switch self {
        case .jackpot: return "Best odds at the jackpot"
        case .win100: return "Best odds of winning at least $100"
        case .win1000: return "Best odds of winning at least $1,000"
        case .double: return "Best odds of doubling your money"
        }
    }

    var subtitle: String {
        switch self {
        case .jackpot: return "Maximise your chance at Group 1, however small"
        case .win100: return "A modest win, as often as the math allows"
        case .win1000: return "A meaningful win. Rarer, needs more matches"
        case .double: return "Win at least 2× whatever you spend"
        }
    }
}

struct PickRecommendation {
    let title: String
    let odds: String
    let oddsNote: String
    let math: String
}

enum PicksMath {
    /// Reference jackpot used when sizing goals. The upcoming draw's
    /// `estimatedJackpot` should be threaded through here once PicksView can
    /// reach it; until then this is a placeholder of the right magnitude.
    static let referenceJackpot = 1_500_000.0

    /// Prize group for a single line matching `main` of the six main numbers,
    /// where `additional` is 1 when the line also holds the drawn additional
    /// number.
    ///
    /// Singapore Pools splits the 5-, 4- and 3-match lines into two groups
    /// each depending on the additional number. Keying prizes off the main
    /// match count alone — as this file used to — collapses G2 into G3, G4
    /// into G5 and G6 into G7, so the additional-number tiers simply never
    /// pay out. That understated "win at least $100" by 3.4x on budgets too
    /// small for a system bet, because G4 (~$391) was invisible and the model
    /// demanded five matches to clear $100 instead of four-plus-additional.
    static func prizeGroup(main: Int, additional: Int) -> Int? {
        switch (main, additional) {
        case (6, _): return 1
        case (5, 1): return 2
        case (5, 0): return 3
        case (4, 1): return 4
        case (4, 0): return 5
        case (3, 1): return 6
        case (3, 0): return 7
        default: return nil
        }
    }

    /// Prize per line for a group. Shares `PrizeGroupEstimate` with
    /// EVMath.swift so the app cannot carry two disagreeing prize tables.
    static func prizeAmount(group: Int, jackpot: Double) -> Double {
        switch group {
        case 1: return jackpot
        case 2: return PrizeGroupEstimate.g2Typical
        case 3: return PrizeGroupEstimate.g3Typical
        case 4: return PrizeGroupEstimate.g4Typical
        case 5: return PrizeGroupEstimate.g5Fixed
        case 6: return PrizeGroupEstimate.g6Fixed
        case 7: return PrizeGroupEstimate.g7Fixed
        default: return 0
        }
    }

    /// Total payout of one k-number entry when `main` of its numbers are
    /// winning numbers and `additional` (0 or 1) is the drawn additional
    /// number. Sums across every C(k,6) sub-line the entry covers, which is
    /// why a system entry can collect several tiers from one draw.
    static func entryPayout(main: Int, additional: Int, numbersChosen k: Int, jackpot: Double) -> Double {
        guard main >= 3 else { return 0 }
        let others = k - main - additional
        var total = 0.0
        for j in 3...main {
            for i in 0...additional {
                let othersNeeded = 6 - j - i
                guard othersNeeded >= 0, let group = prizeGroup(main: j, additional: i) else { continue }
                let lines = Combinatorics.nCr(main, j)
                    * Combinatorics.nCr(additional, i)
                    * Combinatorics.nCr(others, othersNeeded)
                guard lines > 0 else { continue }
                total += lines * prizeAmount(group: group, jackpot: jackpot)
            }
        }
        return total
    }

    /// P(one k-number entry pays at least `target`), over the exact joint
    /// distribution of (main matches, additional matched).
    static func probabilityReaching(target: Double, numbersChosen k: Int, jackpot: Double) -> Double {
        var probability = 0.0
        for main in 0...6 {
            for additional in 0...1 {
                let others = k - main - additional
                guard others >= 0 else { continue }
                let stateProbability = Combinatorics.nCr(6, main)
                    * Combinatorics.nCr(1, additional)
                    * Combinatorics.nCr(42, others)
                    / Combinatorics.nCr(49, k)
                guard stateProbability > 0 else { continue }
                if entryPayout(main: main, additional: additional, numbersChosen: k, jackpot: jackpot) >= target {
                    probability += stateProbability
                }
            }
        }
        return probability
    }

    /// The least demanding outcome that still reaches `target`, for the
    /// explanation copy: the fewest main matches that can get there, and
    /// whether the additional number is needed at that count.
    static func easiestQualifyingOutcome(
        target: Double,
        numbersChosen k: Int,
        jackpot: Double
    ) -> (main: Int, needsAdditional: Bool)? {
        for main in 3...6 {
            if entryPayout(main: main, additional: 0, numbersChosen: k, jackpot: jackpot) >= target {
                return (main, false)
            }
            if entryPayout(main: main, additional: 1, numbersChosen: k, jackpot: jackpot) >= target {
                return (main, true)
            }
        }
        return nil
    }

    static func recommendation(budget: Int, goal: PickGoal) -> PickRecommendation {
        switch goal {
        case .jackpot:
            return jackpotRecommendation(budget: budget)
        case .win100:
            return targetRecommendation(budget: budget, target: 100, targetLabel: "at least SGD 100")
        case .win1000:
            return targetRecommendation(budget: budget, target: 1000, targetLabel: "at least SGD 1,000")
        case .double:
            return targetRecommendation(
                budget: budget,
                target: Double(budget * 2),
                targetLabel: "at least SGD \((budget * 2).formatted())"
            )
        }
    }

    /// Every $1 line has identical jackpot odds, so the best jackpot play
    /// is simply the most distinct Ordinary lines.
    private static func jackpotRecommendation(budget: Int) -> PickRecommendation {
        let totalCombinations = 13_983_816.0
        let odds = Int((totalCombinations / Double(max(budget, 1))).rounded())
        return PickRecommendation(
            title: "\(budget.formatted())× Ordinary, all different",
            odds: "1 in \(odds.formatted())",
            oddsNote: "chance of hitting the jackpot",
            math: "Every $1 line has the same 1 in 13,983,816 jackpot chance, no matter the bet type. So the best jackpot strategy is simply the most distinct lines: \(budget.formatted()) different Ordinary entries. System bets don't improve this; they just package the same lines differently."
        )
    }

    /// For target goals, pick the bet type maximising P(win ≥ target):
    /// entryPayout(m) sums the prize tiers a single entry collects at m
    /// main-number matches; `need` is the smallest m reaching the target;
    /// pEntry is hypergeometric; pAny = 1 − (1 − pEntry)^count.
    private static func targetRecommendation(budget: Int, target: Double, targetLabel: String) -> PickRecommendation {
        struct SystemCandidate {
            let name: String
            let unitCost: Int
            let numbersChosen: Int
        }
        let candidates = [
            SystemCandidate(name: "Ordinary", unitCost: 1, numbersChosen: 6),
            SystemCandidate(name: "System 7", unitCost: 7, numbersChosen: 7),
            SystemCandidate(name: "System 8", unitCost: 28, numbersChosen: 8),
            SystemCandidate(name: "System 9", unitCost: 84, numbersChosen: 9),
        ].filter { budget >= $0.unitCost }

        var best: (candidate: SystemCandidate, count: Int, pAny: Double)?

        for system in candidates {
            let count = budget / system.unitCost
            let pEntry = probabilityReaching(
                target: target,
                numbersChosen: system.numbersChosen,
                jackpot: referenceJackpot
            )
            guard pEntry > 0 else { continue }
            // Entries share one draw, so they are not strictly independent.
            // Distinct entries are mildly negatively correlated, which makes
            // this slightly conservative — hence "estimate" in the copy.
            let pAny = 1 - pow(1 - pEntry, Double(count))
            if best == nil || pAny > best!.pAny {
                best = (system, count, pAny)
            }
        }

        guard let best, best.pAny > 0 else {
            return PickRecommendation(
                title: "No play reaches that target",
                odds: "n/a",
                oddsNote: "",
                math: "At this budget, no single prize tier a bet can reach pays that much. Try a smaller target or bigger budget."
            )
        }

        let odds = Int((1 / best.pAny).rounded())
        let outcome = easiestQualifyingOutcome(
            target: target,
            numbersChosen: best.candidate.numbersChosen,
            jackpot: referenceJackpot
        )
        let needLabel: String = {
            guard let outcome else { return "the right combination" }
            let base = [
                3: "just 3 winning numbers",
                4: "4 winning numbers",
                5: "5 winning numbers",
                6: "all 6 winning numbers",
            ][outcome.main] ?? "\(outcome.main) winning numbers"
            return outcome.needsAdditional ? "\(base) plus the additional number" : base
        }()
        let overlapNote = best.candidate.numbersChosen > 6
            ? "A \(best.candidate.name) entry overlaps its lines heavily, so one lucky draw pays several prize tiers at once. "
            : ""

        return PickRecommendation(
            title: "\(best.count.formatted())× \(best.candidate.name)",
            odds: "≈ 1 in \(odds.formatted())",
            oddsNote: "chance of winning \(targetLabel) (estimate)",
            math: "\(overlapNote)To win \(targetLabel), one of your \(best.count.formatted()) entries needs \(needLabel) among its \(best.candidate.numbersChosen) picks: roughly a 1 in \(odds.formatted()) draw. This structure gives the best odds of any at this budget. Estimate only, since the bigger prize groups are shared between winners, so exact payouts vary by draw."
        )
    }
}

struct PicksView: View {
    @Environment(AppState.self) private var appState
    @State private var goal: PickGoal = .jackpot
    @State private var email = ""
    @State private var emailSaved = UserDefaults.standard.bool(forKey: AppStorageKeys.premiumInterestEmailSaved)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    BudgetCard(showsSyncedPill: true)
                    goalCard
                    recommendationCard
                    premiumTeaser
                    Text("Every combination is equally likely to be drawn. These picks optimise structure, not luck. Play responsibly.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            // Tapping or scrolling anywhere else on the page exits the
            // budget field's edit mode (see BudgetCard).
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Picks")
        }
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What are you aiming for?").font(.title2.bold())
            ForEach(PickGoal.allCases) { candidate in
                Button {
                    goal = candidate
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(candidate.title).font(.headline).foregroundStyle(.primary)
                        Text(candidate.subtitle).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(goal == candidate ? Color.accentColor.opacity(0.12) : Color.clear)
                            .stroke(goal == candidate ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var recommendationCard: some View {
        let recommendation = PicksMath.recommendation(budget: appState.budget, goal: goal)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Recommended play").font(.title2.bold())
            Text(recommendation.title).font(.title3.bold())
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(recommendation.odds).font(.title3.bold()).foregroundStyle(.tint)
                Text(recommendation.oddsNote).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            Text(recommendation.math).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    @ViewBuilder
    private var premiumTeaser: some View {
        if emailSaved {
            // Remembered across launches, so we never ask again.
            VStack(alignment: .leading, spacing: 8) {
                Label("You're on the list", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text("You're awesome, thanks for signing up! You'll be the first to hear about promos and updates, and the moment the premium version launches, your 50% off is locked in.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Want picks tailored to you?").font(.headline)
                Text("More detailed, customised combinations are coming in a future premium version. Leave your email for 50% off at launch.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("you@email.com", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Notify me") {
                        Task { await saveEmail() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!email.contains("@"))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
    }

    private func saveEmail() async {
        struct InterestRow: Encodable {
            let email: String
            let device_id: UUID
        }
        do {
            _ = try await SupabaseClients.data
                .from("premium_interest")
                .insert(InterestRow(email: email.trimmingCharacters(in: .whitespaces), device_id: DeviceIdentity.current))
                .execute()
            markSaved()
        } catch let error as PostgrestError where error.code == "23505" {
            // Unique-violation: this email is already registered, which
            // counts as saved.
            markSaved()
        } catch {
            // Fallback for error shapes that don't surface a structured code:
            // a duplicate registration still counts as saved. Any other
            // failure leaves the button active so the user can retry.
            let text = String(describing: error).lowercased()
            if text.contains("duplicate") || text.contains("23505") {
                markSaved()
            }
        }
    }

    private func markSaved() {
        UserDefaults.standard.set(true, forKey: AppStorageKeys.premiumInterestEmailSaved)
        emailSaved = true
    }
}

#Preview {
    PicksView()
        .environment(AppState())
}

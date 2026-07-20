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
        case .win1000: return "A meaningful win — rarer, needs more matches"
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
    /// Approximate prize per line by match count (SG Pools tiers; the 5- and
    /// 6-match groups are pool-shared, so these are reference estimates).
    private static let approximatePrize: [Int: Double] = [3: 10, 4: 50, 5: 1500, 6: 1_500_000]

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
            title: "\(budget.formatted())× Ordinary — all different",
            odds: "1 in \(odds.formatted())",
            oddsNote: "chance of hitting the jackpot",
            math: "Every $1 line has the same 1-in-13,983,816 jackpot chance, no matter the bet type. So the best jackpot strategy is simply the most distinct lines: \(budget.formatted()) different Ordinary entries. System bets don't improve this — they just package the same lines differently."
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

        var best: (candidate: SystemCandidate, count: Int, need: Int, pAny: Double)?

        for system in candidates {
            let count = budget / system.unitCost
            let k = system.numbersChosen

            func entryPayout(matches m: Int) -> Double {
                var total = 0.0
                for j in 3...m {
                    total += Combinatorics.nCr(m, j) * Combinatorics.nCr(k - m, 6 - j) * (approximatePrize[j] ?? 0)
                }
                return total
            }

            guard let need = (3...6).first(where: { entryPayout(matches: $0) >= target }) else { continue }

            var pEntry = 0.0
            for m in need...6 {
                pEntry += Combinatorics.nCr(6, m) * Combinatorics.nCr(43, k - m) / Combinatorics.nCr(49, k)
            }
            let pAny = 1 - pow(1 - pEntry, Double(count))
            if best == nil || pAny > best!.pAny {
                best = (system, count, need, pAny)
            }
        }

        guard let best, best.pAny > 0 else {
            return PickRecommendation(
                title: "No play reaches that target",
                odds: "—",
                oddsNote: "",
                math: "At this budget, no single prize tier a bet can reach pays that much. Try a smaller target or bigger budget."
            )
        }

        let odds = Int((1 / best.pAny).rounded())
        let needLabel = [
            3: "just 3 winning numbers",
            4: "4 winning numbers",
            5: "5 winning numbers",
            6: "all 6 winning numbers",
        ][best.need] ?? "\(best.need) winning numbers"
        let overlapNote = best.candidate.numbersChosen > 6
            ? "A \(best.candidate.name) entry overlaps its lines heavily, so one lucky draw pays several prize tiers at once. "
            : ""

        return PickRecommendation(
            title: "\(best.count.formatted())× \(best.candidate.name)",
            odds: "≈ 1 in \(odds.formatted())",
            oddsNote: "chance of winning \(targetLabel) (estimate)",
            math: "\(overlapNote)To win \(targetLabel), one of your \(best.count.formatted()) entries needs \(needLabel) among its \(best.candidate.numbersChosen) picks — roughly a 1-in-\(odds.formatted()) draw. This structure gives the best odds of any at this budget. Estimate only: the bigger prize groups are pool-shared, so exact payouts vary by draw."
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
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Picks")
        }
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What are you aiming for?").font(.headline)
            ForEach(PickGoal.allCases) { candidate in
                Button {
                    goal = candidate
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(candidate.title).font(.subheadline.bold()).foregroundStyle(.primary)
                        Text(candidate.subtitle).font(.caption).foregroundStyle(.secondary)
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
            Text("Recommended play").font(.headline)
            Text(recommendation.title).font(.title3.bold())
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(recommendation.odds).font(.title3.bold()).foregroundStyle(.tint)
                Text(recommendation.oddsNote).font(.caption).foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            Text(recommendation.math).font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var premiumTeaser: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Want picks tailored to you?").font(.subheadline.bold())
            Text("More detailed, customised combinations are coming in a future premium version. Leave your email for 50% off at launch.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField("you@email.com", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button(emailSaved ? "✓ Saved" : "Notify me") {
                    Task { await saveEmail() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(emailSaved || !email.contains("@"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func saveEmail() async {
        struct InterestRow: Encodable {
            let email: String
            let device_id: UUID
        }
        // Best-effort: record locally first so the UX never loses the
        // signup, then push to Supabase (duplicate emails no-op server-side).
        UserDefaults.standard.set(true, forKey: AppStorageKeys.premiumInterestEmailSaved)
        emailSaved = true
        _ = try? await SupabaseClients.data
            .from("premium_interest")
            .insert(InterestRow(email: email.trimmingCharacters(in: .whitespaces), device_id: DeviceIdentity.current))
            .execute()
    }
}

#Preview {
    PicksView()
        .environment(AppState())
}

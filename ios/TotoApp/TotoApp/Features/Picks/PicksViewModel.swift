import Foundation
import Observation

// MARK: – Goal definitions

enum PicksGoal: String, CaseIterable, Identifiable {
    case jackpot
    case win100
    case win1000
    case doubleMoney

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .jackpot:   return "Best odds at the jackpot"
        case .win100:    return "Best odds of winning at least $100"
        case .win1000:   return "Best odds of winning at least $1,000"
        case .doubleMoney: return "Best odds of doubling your money"
        }
    }

    var systemImage: String {
        switch self {
        case .jackpot:   return "dollarsign.circle.fill"
        case .win100:    return "banknote.fill"
        case .win1000:   return "bag.fill"
        case .doubleMoney: return "arrow.up.forward.circle.fill"
        }
    }

    func target(budget: Double) -> Double {
        switch self {
        case .jackpot:   return 0 // special-cased
        case .win100:    return 100
        case .win1000:   return 1_000
        case .doubleMoney: return budget
        }
    }
}

// MARK: – Recommendation models

struct PicksJackpotResult {
    let lines: Int
    let oddsDenominator: Int
    let explanation: String
}

struct PicksTargetResult {
    let bestBet: BetType
    let entries: Int
    let target: Double
    let oddsDenominator: Int
    let explanation: String
}

// MARK: – ViewModel

@Observable
final class PicksViewModel {
    let budgetState: BudgetState
    var selectedGoal: PicksGoal = .jackpot
    private(set) var currentJackpot: Double?
    private(set) var isLoading = true
    private(set) var errorMessage: String?

    // Email capture
    var email: String = ""
    private(set) var emailSaved = false

    private let drawsRepository = DrawsRepository()

    init(budgetState: BudgetState) {
        self.budgetState = budgetState
    }

    // MARK: – Computed results

    var jackpotResult: PicksJackpotResult {
        let rec = PicksMath.jackpotRecommendation(budget: budgetState.budget)
        return PicksJackpotResult(
            lines: rec.lines,
            oddsDenominator: rec.oddsDenominator,
            explanation: rec.lines == 1
                ? "Buy 1 Ordinary entry for $1. Your odds are 1 in 13,983,816 — every $1 Ordinary line has identical jackpot odds."
                : "Buy \(rec.lines) distinct Ordinary entries for $\(Int(budgetState.budget)). Each $1 line has identical jackpot odds; system bets overlap combinations and don't improve jackpot chances. Estimated odds: 1 in \(rec.oddsDenominator)."
        )
    }

    var targetResult: PicksTargetResult? {
        let t = selectedGoal.target(budget: budgetState.budget)
        guard let best = PicksMath.bestBetForTarget(budget: budgetState.budget, target: t) else {
            return nil
        }

        let oddsD = best.pAny > 0 ? max(1, Int(round(1.0 / best.pAny))) : Int.max

        var explanation: String
        if !best.reached {
            explanation = "No tier combination within a single \(best.betType.displayName) entry can reach $\(Int(t)) at typical prize levels. Try increasing your budget or choosing a different goal."
        } else {
            explanation = "Buy \(best.entries) × \(best.betType.displayName) entries (\(best.betType.displayName) costs $\(Int(best.betType.cost)) each) — you stay within your $\(Int(budgetState.budget)) budget. If the right numbers come up, at least one of your entries should pay out $\(Int(t))+."

            if best.pAny > 0 {
                explanation += "\nEstimated odds: roughly 1 in \(oddsD). Note: Groups 2–4 are pari-mutuel and estimates."
            }
        }

        return PicksTargetResult(
            bestBet: best.betType,
            entries: best.entries,
            target: t,
            oddsDenominator: oddsD,
            explanation: explanation
        )
    }

    var currentResultExplanation: String {
        switch selectedGoal {
        case .jackpot:
            return jackpotResult.explanation
        default:
            return targetResult?.explanation ?? "No recommendation available for this goal and budget."
        }
    }

    // MARK: – Email capture

    func saveEmail() {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        UserDefaults.standard.set(email.trimmingCharacters(in: .whitespaces), forKey: "picks_premium_email")
        emailSaved = true
    }

    // MARK: – Data loading

    @MainActor
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            if let upcoming = try await drawsRepository.upcomingDraw() {
                currentJackpot = upcoming.estimatedJackpot
            } else if let latest = try await drawsRepository.latestDraw() {
                currentJackpot = latest.jackpotWon ? nil : latest.jackpotAmount
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

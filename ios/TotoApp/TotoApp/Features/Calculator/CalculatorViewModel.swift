import Foundation

@Observable
final class CalculatorViewModel {
    let budgetState: BudgetState
    private(set) var currentJackpot: Double?
    private(set) var isLoading = true
    private(set) var errorMessage: String?

    private let drawsRepository: DrawsRepository

    init(drawsRepo: DrawsRepository = DrawsRepository(), budgetState: BudgetState = BudgetState()) {
        drawsRepository = drawsRepo
        self.budgetState = budgetState
    }

    /// Expected value per dollar spent for an Ordinary ticket at the
    /// current jackpot (e.g. 0.58 = 58¢ back per $1).
    var ordinaryEV: Double? {
        guard let currentJackpot else { return nil }
        return EVMath.expectedValue(betType: .ordinary, jackpot: currentJackpot)
    }

    /// Jackpot required for a single Ordinary ticket to reach $1.00 EV
    /// (break-even), holding G2-G4 estimates fixed.
    var breakEvenJackpot: Double {
        EVMath.breakEvenJackpot()
    }

    /// Per-bet-type breakdown of what the current budget buys.
    var affordableEntries: [(betType: BetType, count: Int, cost: Double)] {
        let budget = budgetState.budget
        return BetType.allCases.map { betType in
            let count = Int(budget / betType.cost)
            let cost = Double(count) * betType.cost
            return (betType, count, cost)
        }
    }

    @MainActor
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            if let upcoming = try await drawsRepository.upcomingDraw() {
                currentJackpot = upcoming.estimatedJackpot
            } else if let latest = try await drawsRepository.latestDraw() {
                // Fallback: no upcoming-draw row yet, estimate from the last
                // known jackpot figure rather than showing nothing.
                currentJackpot = latest.jackpotWon ? nil : latest.jackpotAmount
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

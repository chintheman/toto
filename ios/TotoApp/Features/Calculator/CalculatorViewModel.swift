import Foundation

/// A "What $X can buy" row: how many of a bet type the budget affords.
struct AffordableCombo: Identifiable {
    let betType: BetType
    let count: Int
    let spend: Int

    var id: String { betType.id }
}

@Observable
final class CalculatorViewModel {
    private(set) var currentJackpot: Double?
    private(set) var isLoading = true
    private(set) var errorMessage: String?

    private let drawsRepository: DrawsRepository

    init(drawsRepository: DrawsRepository = DrawsRepository()) {
        self.drawsRepository = drawsRepository
    }

    /// Design-changes §4: every affordable bet type, count-formatted, with
    /// "$N of $budget" cost framing. Variance framing only — no claim that
    /// any allocation improves expected return.
    func affordableCombos(budget: Int) -> [AffordableCombo] {
        BetType.allCases.compactMap { type in
            let unit = Int(type.cost)
            let count = budget / unit
            guard count >= 1 else { return nil }
            return AffordableCombo(betType: type, count: count, spend: count * unit)
        }
    }

    var ordinaryEV: Double? {
        guard let currentJackpot else { return nil }
        return EVMath.expectedValue(betType: .ordinary, jackpot: currentJackpot)
    }

    var breakEvenJackpot: Double {
        EVMath.breakEvenJackpot()
    }

    /// Knob position along the poor-value → break-even gauge (0...1).
    var gaugeFraction: Double {
        min(max(ordinaryEV ?? 0, 0), 1)
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

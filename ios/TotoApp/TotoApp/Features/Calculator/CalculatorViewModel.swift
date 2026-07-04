import Foundation

@Observable
final class CalculatorViewModel {
    var budget: Double = 100
    private(set) var currentJackpot: Double?
    private(set) var isLoading = true
    private(set) var errorMessage: String?

    private let drawsRepository = DrawsRepository()

    var oddsByBetType: [BetOdds] {
        guard let currentJackpot else { return [] }
        return BetType.allCases.map { EVMath.odds(for: $0, jackpot: currentJackpot) }
    }

    var ordinaryEV: Double? {
        guard let currentJackpot else { return nil }
        return EVMath.expectedValue(betType: .ordinary, jackpot: currentJackpot)
    }

    var isPositiveEV: Bool {
        (ordinaryEV ?? 0) >= 1.0
    }

    var breakEvenJackpot: Double {
        EVMath.breakEvenJackpot()
    }

    var jackpotGapToBreakEven: Double? {
        guard let currentJackpot else { return nil }
        return breakEvenJackpot - currentJackpot
    }

    /// How many System 7 entries the given budget affords, spent to
    /// maximise number coverage across all 49 numbers -- mirrors the
    /// research site's "spread beats concentration" strategy guidance.
    var affordableSystem7Count: Int {
        Int(budget / BetType.system7.cost)
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

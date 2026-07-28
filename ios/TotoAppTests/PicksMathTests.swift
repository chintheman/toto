import XCTest
@testable import TotoApp

/// Regression cover for PicksMath, which previously keyed prizes off the main
/// match count alone and so never awarded Groups 2, 4 or 6 — the tiers that
/// require the drawn additional number.
final class PicksMathTests: XCTestCase {
    private let jackpot = PicksMath.referenceJackpot

    // MARK: - Prize group mapping

    /// The seven Singapore Pools groups, including the three that only exist
    /// when the additional number is matched.
    func testPrizeGroupMapping() {
        XCTAssertEqual(PicksMath.prizeGroup(main: 6, additional: 0), 1)
        XCTAssertEqual(PicksMath.prizeGroup(main: 5, additional: 1), 2)
        XCTAssertEqual(PicksMath.prizeGroup(main: 5, additional: 0), 3)
        XCTAssertEqual(PicksMath.prizeGroup(main: 4, additional: 1), 4)
        XCTAssertEqual(PicksMath.prizeGroup(main: 4, additional: 0), 5)
        XCTAssertEqual(PicksMath.prizeGroup(main: 3, additional: 1), 6)
        XCTAssertEqual(PicksMath.prizeGroup(main: 3, additional: 0), 7)
        XCTAssertNil(PicksMath.prizeGroup(main: 2, additional: 1))
    }

    /// Picks and the EV calculator must read one prize table, not two.
    func testPrizeAmountsMatchEVMathEstimates() {
        XCTAssertEqual(PicksMath.prizeAmount(group: 2, jackpot: jackpot), PrizeGroupEstimate.g2Typical)
        XCTAssertEqual(PicksMath.prizeAmount(group: 3, jackpot: jackpot), PrizeGroupEstimate.g3Typical)
        XCTAssertEqual(PicksMath.prizeAmount(group: 4, jackpot: jackpot), PrizeGroupEstimate.g4Typical)
        XCTAssertEqual(PicksMath.prizeAmount(group: 1, jackpot: jackpot), jackpot)
    }

    // MARK: - Entry payouts

    /// An Ordinary line with 4 main matches is G5 ($50). The same 4 matches
    /// plus the additional number is G4 (~$391) — nearly 8x more, and the
    /// distinction the old model could not represent.
    func testAdditionalNumberLiftsFourMatchPayout() {
        let withoutAdditional = PicksMath.entryPayout(main: 4, additional: 0, numbersChosen: 6, jackpot: jackpot)
        let withAdditional = PicksMath.entryPayout(main: 4, additional: 1, numbersChosen: 6, jackpot: jackpot)
        XCTAssertEqual(withoutAdditional, PrizeGroupEstimate.g5Fixed, accuracy: 0.01)
        XCTAssertEqual(withAdditional, PrizeGroupEstimate.g4Typical, accuracy: 0.01)
        XCTAssertGreaterThan(withAdditional, withoutAdditional)
    }

    /// Fewer than three main matches never pays.
    func testBelowThreeMatchesPaysNothing() {
        for main in 0...2 {
            XCTAssertEqual(PicksMath.entryPayout(main: main, additional: 1, numbersChosen: 9, jackpot: jackpot), 0)
        }
    }

    /// A system entry collects several tiers from one draw, because many of
    /// its C(k,6) sub-lines win at once.
    func testSystemEntryCollectsMultipleTiers() {
        let ordinary = PicksMath.entryPayout(main: 3, additional: 0, numbersChosen: 6, jackpot: jackpot)
        let system9 = PicksMath.entryPayout(main: 3, additional: 0, numbersChosen: 9, jackpot: jackpot)
        XCTAssertEqual(ordinary, PrizeGroupEstimate.g7Fixed, accuracy: 0.01)
        // C(3,3) * C(6,3) = 20 G7 lines.
        XCTAssertEqual(system9, 20 * PrizeGroupEstimate.g7Fixed, accuracy: 0.01)
    }

    // MARK: - Probabilities

    /// P(any prize) for an Ordinary ticket is the published 1.86%, and a
    /// $10 target is cleared by any prize at all, so the two must agree.
    func testOrdinaryReachingSmallestPrizeMatchesPublishedOdds() {
        let probability = PicksMath.probabilityReaching(target: 10, numbersChosen: 6, jackpot: jackpot)
        XCTAssertEqual(probability, 0.01864, accuracy: 0.0001)
    }

    /// The regression itself. On a $1 budget only an Ordinary line is
    /// affordable. Group 4 (4 main + additional, ~$391) clears a $100 target,
    /// so the odds are 1 in 15,730. The old model had no G4 and demanded five
    /// matches, reporting 1 in 53,992 — 3.4x too pessimistic.
    func testWinAtLeast100OnOrdinaryUsesGroupFour() {
        let probability = PicksMath.probabilityReaching(target: 100, numbersChosen: 6, jackpot: jackpot)
        XCTAssertEqual(1 / probability, 15_730, accuracy: 5)

        let outcome = PicksMath.easiestQualifyingOutcome(target: 100, numbersChosen: 6, jackpot: jackpot)
        XCTAssertEqual(outcome?.main, 4)
        XCTAssertEqual(outcome?.needsAdditional, true)
    }

    /// $1,000 needs a Group 3 (5 main, ~$1,612); four-plus-additional at $391
    /// is not enough, so this target still requires five matches.
    func testWinAtLeast1000StillNeedsFiveMatches() {
        let outcome = PicksMath.easiestQualifyingOutcome(target: 1000, numbersChosen: 6, jackpot: jackpot)
        XCTAssertEqual(outcome?.main, 5)
        XCTAssertEqual(outcome?.needsAdditional, false)
        let probability = PicksMath.probabilityReaching(target: 1000, numbersChosen: 6, jackpot: jackpot)
        XCTAssertEqual(1 / probability, 53_992, accuracy: 10)
    }

    /// Doubling a $1 stake needs only $2, which the smallest prize covers, so
    /// it collapses to the any-prize odds of 1 in 54.
    func testDoublingASingleDollarIsTheAnyPrizeOdds() {
        let probability = PicksMath.probabilityReaching(target: 2, numbersChosen: 6, jackpot: jackpot)
        XCTAssertEqual(1 / probability, 54, accuracy: 1)
    }

    /// Raising the target can never improve the odds.
    func testProbabilityIsMonotonicInTarget() {
        var previous = Double.infinity
        for target in [2.0, 100.0, 1000.0, 100_000.0] {
            let probability = PicksMath.probabilityReaching(target: target, numbersChosen: 9, jackpot: jackpot)
            XCTAssertLessThanOrEqual(probability, previous)
            previous = probability
        }
    }

    // MARK: - Recommendations

    /// Every goal must produce a recommendation at every budget the UI offers.
    func testRecommendationsExistForAllGoalsAndBudgets() {
        for budget in [1, 5, 10, 20, 50, 100, 200, 500] {
            for goal in PickGoal.allCases {
                let recommendation = PicksMath.recommendation(budget: budget, goal: goal)
                XCTAssertFalse(recommendation.title.isEmpty)
                XCTAssertFalse(recommendation.odds.isEmpty)
            }
        }
    }

    /// Jackpot odds scale exactly with the number of distinct lines bought.
    func testJackpotGoalScalesWithBudget() {
        let recommendation = PicksMath.recommendation(budget: 100, goal: .jackpot)
        XCTAssertTrue(recommendation.odds.contains("139,838"), recommendation.odds)
    }
}

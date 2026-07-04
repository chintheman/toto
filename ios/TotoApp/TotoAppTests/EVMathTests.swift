import XCTest
@testable import TotoApp

final class EVMathTests: XCTestCase {
    /// Reference value from Singapore Pools' published Ordinary-ticket odds
    /// (also independently confirmed in the project's reference material):
    /// P(any prize) = 1.86%.
    func testOrdinaryAnyPrizeMatchesPublishedOdds() {
        let probability = EVMath.probabilityAnyPrize(.ordinary)
        XCTAssertEqual(probability, 0.01864, accuracy: 0.0001)
    }

    /// Jackpot odds for a single Ordinary ticket: 1 in C(49,6) = 1 in 13,983,816.
    func testOrdinaryJackpotOdds() {
        let probability = EVMath.probabilityJackpot(.ordinary)
        XCTAssertEqual(1 / probability, 13_983_816, accuracy: 1)
    }

    /// System 7 buys exactly 7 combinations for $7, so its "any prize" odds
    /// must exceed a single Ordinary ticket's, since it's playing 7x the
    /// combinations across a larger pool.
    func testSystem7BeatsOrdinaryOnAnyPrizeOdds() {
        XCTAssertGreaterThan(EVMath.probabilityAnyPrize(.system7), EVMath.probabilityAnyPrize(.ordinary))
    }

    /// A system bet's cost should equal C(numbersChosen, 6) dollars (each
    /// underlying combination is a $1 Ordinary-equivalent).
    func testSystemBetCosts() {
        XCTAssertEqual(BetType.ordinary.cost, 1)
        XCTAssertEqual(BetType.system7.cost, 7)
        XCTAssertEqual(BetType.system8.cost, 28)
        XCTAssertEqual(BetType.system9.cost, 84)
    }

    /// Below the break-even jackpot, EV must be < 1.0 (a loss on average);
    /// above it, EV must be >= 1.0.
    func testBreakEvenJackpotIsConsistentWithEV() {
        let breakEven = EVMath.breakEvenJackpot()
        let evBelow = EVMath.expectedValue(betType: .ordinary, jackpot: breakEven - 500_000)
        let evAbove = EVMath.expectedValue(betType: .ordinary, jackpot: breakEven + 500_000)
        XCTAssertLessThan(evBelow, 1.0)
        XCTAssertGreaterThan(evAbove, 1.0)
    }
}

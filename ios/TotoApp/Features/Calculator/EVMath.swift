import Foundation

/// TOTO 6/49 probability + expected-value math. This mirrors research
/// that's already public on the companion research site (not secret — see
/// ios/README.md and the project plan for what IS kept secret: the paid
/// recommendation engine's specific algorithm, which lives server-side only
/// and nowhere near this file).
///
/// CALIBRATION NOTE: the combinatorial probabilities below (P(any prize),
/// P(jackpot), etc.) are exact and verified against Singapore Pools'
/// published base odds (Ordinary $1 -> 1.86% P(any), which this derivation
/// reproduces to 4 decimal places). The pari-mutuel prize AMOUNTS for
/// Groups 1-4 are not exact, though -- G1 (jackpot) is a live input, but
/// G2-G4 use fixed typical mid-range figures from published reference
/// material, since actual pari-mutuel payouts depend on real ticket sales
/// data we don't have yet. Once the historical backfill is populated,
/// recalibrate `PrizeGroupEstimate.typical` against real scraped payouts.
enum BetType: String, CaseIterable, Identifiable {
    case ordinary, system7, system8, system9, system10

    var id: String { rawValue }

    /// N: how many numbers you pick (forms C(N,6) combinations).
    var numbersChosen: Int {
        switch self {
        case .ordinary: return 6
        case .system7: return 7
        case .system8: return 8
        case .system9: return 9
        case .system10: return 10
        }
    }

    var cost: Double {
        Double(Int(Combinatorics.nCr(numbersChosen, 6))) // combos * $1/combo
    }

    var displayName: String {
        switch self {
        case .ordinary: return "Ordinary"
        case .system7: return "System 7"
        case .system8: return "System 8"
        case .system9: return "System 9"
        case .system10: return "System 10"
        }
    }

    /// One-line description for the Calculator's "What $X can buy" rows.
    var coverageDescription: String {
        switch self {
        case .ordinary: return "6 numbers, one line each"
        case .system7: return "7 numbers, 7 lines of coverage"
        case .system8: return "8 numbers, 28 lines of coverage"
        case .system9: return "9 numbers, 84 lines of coverage"
        case .system10: return "10 numbers, 210 lines of coverage"
        }
    }
}

/// Fixed (G5-G7) and typical-range (G1-G4) prize amounts. G1 is always
/// supplied live (the current/upcoming jackpot); the rest are published
/// reference midpoints pending real recalibration (see file header).
enum PrizeGroupEstimate {
    static let g5Fixed = 50.0
    static let g6Fixed = 25.0
    static let g7Fixed = 10.0
    // Pari-mutuel reference points taken from the design mock's real draw
    // detail (G2 $121,410 / G3 $1,612 / G4 $391) rather than optimistic
    // midpoints — still estimates until recalibrated against the scraped
    // payout backfill.
    static let g2Typical = 121_410.0
    static let g3Typical = 1_612.0
    static let g4Typical = 391.0
}

struct BetOdds {
    let betType: BetType
    let probabilityAnyPrize: Double
    let probabilityJackpot: Double
    let expectedValue: Double // dollars returned per dollar spent, e.g. 0.42 = 42 cents back per $1
}

enum EVMath {
    /// For a system bet choosing N numbers, whether you win ANYTHING
    /// reduces to a clean existence argument: you win at least one prize
    /// iff your N-number pool contains at least 3 of the 6 true winning
    /// numbers. (If it contains >=3, you can always construct a winning
    /// 6-number sub-combination from your own pool; if it contains <3, no
    /// 6-number sub-combination ever can, since no combination of your
    /// numbers can produce 3+ matches from fewer than 3 available.) So:
    ///
    ///   P(any prize) = P(a >= 3), where a ~ Hypergeometric(pop=49, K=6, n=N)
    ///
    /// This is verified against Singapore Pools' published Ordinary-ticket
    /// odds (N=6): the formula below reproduces 1.86% exactly.
    static func probabilityAtLeastKMainMatches(numbersChosen n: Int, atLeast k: Int) -> Double {
        let totalCombinations = Combinatorics.nCr(49, n)
        guard totalCombinations > 0 else { return 0 }
        var probabilityBelowK = 0.0
        for matches in 0..<k {
            probabilityBelowK += Combinatorics.nCr(6, matches) * Combinatorics.nCr(43, n - matches)
        }
        return 1 - (probabilityBelowK / totalCombinations)
    }

    static func probabilityAnyPrize(_ betType: BetType) -> Double {
        probabilityAtLeastKMainMatches(numbersChosen: betType.numbersChosen, atLeast: 3)
    }

    /// Jackpot requires all 6 of the true winning numbers to be within your
    /// N-number pool: P(a = 6) = C(6,6) * C(43, N-6) / C(49, N).
    static func probabilityJackpot(_ betType: BetType) -> Double {
        let n = betType.numbersChosen
        let total = Combinatorics.nCr(49, n)
        guard total > 0 else { return 0 }
        return Combinatorics.nCr(43, n - 6) / total
    }

    /// Exact per-group hit probabilities for a SINGLE Ordinary ($1) ticket,
    /// using the full (mainMatches, hitAdditional) joint hypergeometric
    /// over the 6 winning / 1 additional / 42 other split. System bets
    /// (N>6) are excluded from this exact per-group breakdown -- the
    /// combinatorics of "which of your C(N,6) sub-tickets hit which group"
    /// compound quickly, so EV for system bets below approximates their
    /// prize-tier mix using this same per-combination distribution scaled
    /// by combination count, which is directionally right but not an exact
    /// per-group figure the way the N=6 case is.
    private static func ordinaryGroupProbabilities() -> [(group: Int, probability: Double)] {
        let total = Combinatorics.nCr(49, 6)
        func p(_ mainMatches: Int, _ additionalMatches: Int) -> Double {
            Combinatorics.nCr(6, mainMatches) * Combinatorics.nCr(1, additionalMatches)
                * Combinatorics.nCr(42, 6 - mainMatches - additionalMatches) / total
        }
        return [
            (1, p(6, 0)),
            (2, p(5, 1)),
            (3, p(5, 0)),
            (4, p(4, 1)),
            (5, p(4, 0)),
            (6, p(3, 1)),
            (7, p(3, 0)),
        ]
    }

    /// Expected value per dollar spent (1.0 = break-even, >1.0 = +EV) for a
    /// single instance of the given bet type, given the current jackpot.
    static func expectedValue(betType: BetType, jackpot: Double) -> Double {
        let combos = Combinatorics.nCr(betType.numbersChosen, 6)
        let groupProbabilities = ordinaryGroupProbabilities()

        func prize(forGroup group: Int) -> Double {
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

        // Each of the bet's `combos` combinations independently carries the
        // same per-combination prize distribution as a single Ordinary
        // ticket (a reasonable approximation for EV purposes -- overlap
        // between combinations affects the WIN/LOSE correlation structure,
        // not the expected payout, since expectation is linear).
        let expectedReturnPerCombo = groupProbabilities.reduce(0.0) { total, entry in
            total + entry.probability * prize(forGroup: entry.group)
        }

        let totalExpectedReturn = expectedReturnPerCombo * combos
        return totalExpectedReturn / betType.cost
    }

    static func odds(for betType: BetType, jackpot: Double) -> BetOdds {
        BetOdds(
            betType: betType,
            probabilityAnyPrize: probabilityAnyPrize(betType),
            probabilityJackpot: probabilityJackpot(betType),
            expectedValue: expectedValue(betType: betType, jackpot: jackpot)
        )
    }

    /// The jackpot size at which a single Ordinary ticket crosses from -EV
    /// to +EV, holding G2-G4 estimates fixed. Used by CalculatorView to
    /// tell the user "how far from +EV" they are.
    static func breakEvenJackpot(betType: BetType = .ordinary) -> Double {
        let combos = Combinatorics.nCr(betType.numbersChosen, 6)
        let groupProbabilities = ordinaryGroupProbabilities()

        let nonJackpotExpectedReturn = groupProbabilities
            .filter { $0.group != 1 }
            .reduce(0.0) { total, entry in
                let prize: Double
                switch entry.group {
                case 2: prize = PrizeGroupEstimate.g2Typical
                case 3: prize = PrizeGroupEstimate.g3Typical
                case 4: prize = PrizeGroupEstimate.g4Typical
                case 5: prize = PrizeGroupEstimate.g5Fixed
                case 6: prize = PrizeGroupEstimate.g6Fixed
                case 7: prize = PrizeGroupEstimate.g7Fixed
                default: prize = 0
                }
                return total + entry.probability * prize
            } * combos

        let jackpotProbability = groupProbabilities.first { $0.group == 1 }!.probability * combos
        // Solve: (nonJackpotExpectedReturn + jackpotProbability * jackpot) / cost = 1
        return (betType.cost - nonJackpotExpectedReturn) / jackpotProbability
    }
}

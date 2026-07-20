import Foundation

/// Target-based recommendation engine for the Picks tab.
///
/// Calibration note: prize amounts for Groups 1–4 are approximate/pari-mutuel
/// estimates (the actual amounts depend on real ticket-sales data). All results
/// below are labelled "estimate" in the UI.
enum PicksMath {

    // MARK: – Constants

    static let totalCombinations = 13_983_816.0  // C(49,6)
    static let prizeApprox: [Int: Double] = [3: 10, 4: 50, 5: 1_500, 6: 1_500_000]

    // MARK: – Goal 1: Jackpot odds

    /// Best goal-1 recommendation: buy `budget` Ordinary lines.
    /// Simplified odds: 1 in `round(13,983,816 / budget)`.
    struct JackpotRecommendation {
        let oddsDenominator: Int
        let lines: Int
    }

    static func jackpotRecommendation(budget: Double) -> JackpotRecommendation {
        let lines = max(1, Int(budget / BetType.ordinary.cost))
        let oddsDenominator = max(1, Int(round(totalCombinations / Double(lines))))
        return JackpotRecommendation(oddsDenominator: oddsDenominator, lines: lines)
    }

    // MARK: – Goals 2–4: Target-based recommendations

    /// Result for a single bet type: how many entries fit, the probability
    /// that at least one entry reaches the target, and supporting numbers.
    struct TargetResult {
        let betType: BetType
        let entries: Int           // how many of this type the budget buys
        let need: Int              // smallest m (pool matches) hitting the target
        let pEntry: Double         // P(single entry reaches target)
        let pAny: Double           // P(at least one entry reaches target) = 1 - (1-pEntry)^entries
        let reached: Bool          // true if some prize tier can hit the target
    }

    /// For a single entry of type `betType`, the expected total payout across
    /// all its C(k,6) combinations when exactly `m` of the 6 winning numbers
    /// are in the k-number pool.
    ///
    /// formula: Σ_{j=3..m} C(m,j)·C(k−m, 6−j)·prize[j]
    static func entryPayout(m: Int, k: Int) -> Double {
        guard m >= 3 else { return 0 }
        var total = 0.0
        for j in 3...min(m, 6) {
            let ways = Combinatorics.nCr(m, j) * Combinatorics.nCr(k - m, 6 - j)
            total += ways * (prizeApprox[j] ?? 0)
        }
        return total
    }

    /// The smallest `m` (pool matches) for which `entryPayout(m, k) >= target`.
    /// Returns nil if no tier can reach the target.
    static func needForTarget(target: Double, k: Int) -> Int? {
        for m in 3...6 {
            if entryPayout(m: m, k: k) >= target {
                return m
            }
        }
        return nil
    }

    /// Probability that a k-number pool contains exactly `m` winning numbers:
    /// C(6,m)·C(43,k-m)/C(49,k)
    static func probabilityExactlyMMatches(m: Int, k: Int) -> Double {
        guard m >= 0, m <= 6, (k - m) <= 43, (k - m) >= 0 else { return 0 }
        return Combinatorics.nCr(6, m) * Combinatorics.nCr(43, k - m) / Combinatorics.nCr(49, k)
    }

    /// Probability that a SINGLE entry (one k-number pool) reaches the target.
    /// pEntry = Σ_{m=need..6} P(exactly m matches in pool)
    static func pEntry(k: Int, need: Int) -> Double {
        guard need <= 6 else { return 0 }
        var total = 0.0
        for m in need...6 {
            total += probabilityExactlyMMatches(m: m, k: k)
        }
        return total
    }

    /// Probability that at least one of `count` independent entries succeeds,
    /// each with success probability `pEntry`.
    static func pAny(count: Int, pEntry: Double) -> Double {
        guard count > 0 else { return 0 }
        return 1 - pow(1 - pEntry, Double(count))
    }

    /// Evaluate all affordable bet types for a given target and return the
    /// one with the highest `pAny`.
    static func bestBetForTarget(budget: Double, target: Double) -> TargetResult? {
        var results: [TargetResult] = []

        for betType in BetType.allCases {
            let cost = betType.cost
            let entries = max(1, Int(budget / cost))
            let k = betType.numbersChosen

            guard let need = needForTarget(target: target, k: k) else {
                // No tier reaches this target for this bet type — skip it
                results.append(TargetResult(
                    betType: betType,
                    entries: entries,
                    need: 7,  // sentinel: > 6 so pEntry=0
                    pEntry: 0,
                    pAny: 0,
                    reached: false
                ))
                continue
            }

            let pEntryVal = pEntry(k: k, need: need)
            let pAnyVal = pAny(count: entries, pEntry: pEntryVal)

            results.append(TargetResult(
                betType: betType,
                entries: entries,
                need: need,
                pEntry: pEntryVal,
                pAny: pAnyVal,
                reached: true
            ))
        }

        // Return the one with highest pAny. If none reached, return the
        // one that came closest (highest pAny even if zero).
        return results.max { $0.pAny < $1.pAny }
    }
}

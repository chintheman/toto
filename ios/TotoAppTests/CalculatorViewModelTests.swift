import XCTest
@testable import TotoApp

final class CalculatorViewModelTests: XCTestCase {
    /// A live jackpot that doesn't round to any preset's $0.1M bucket:
    /// "Today" plus all 8 presets plus the break-even chip should appear,
    /// nothing deduped.
    func testChipsIncludeLiveAndAllPresetsWhenNoOverlap() {
        let chips = CalculatorViewModel.jackpotChips(currentJackpot: 5_900_838)
        XCTAssertEqual(chips.count, 1 + JackpotPreset.millionsValues.count + 1) // +1 live, +1 break-even
        XCTAssertEqual(chips.first?.selection, .live)
    }

    /// A live jackpot landing exactly on a preset (e.g. today's estimate is
    /// $1,000,000, same as the $1M preset) must not show the same figure
    /// twice in the row.
    func testDuplicatePresetIsDroppedWhenLiveJackpotMatchesIt() {
        let chips = CalculatorViewModel.jackpotChips(currentJackpot: 1_000_000)
        // 1 live + 7 presets + 1 break-even, not 1 + 8 + 1
        XCTAssertEqual(chips.count, JackpotPreset.millionsValues.count + 1)
        XCTAssertTrue(chips.contains { $0.selection == .live })
        XCTAssertFalse(chips.contains { $0.selection == .preset(1_000_000) })
    }

    /// No live jackpot yet (still loading, or a won jackpot with no
    /// upcoming estimate): chips are the 8 presets plus break-even, no
    /// "Today" entry.
    func testChipsArePresetsOnlyWhenNoLiveJackpotYet() {
        let chips = CalculatorViewModel.jackpotChips(currentJackpot: nil)
        XCTAssertEqual(chips.count, JackpotPreset.millionsValues.count + 1)
        XCTAssertFalse(chips.contains { $0.selection == .live })
    }

    /// The break-even chip is always present, always highlighted, and its
    /// selection value is exactly EVMath's break-even jackpot — not a
    /// rounded preset standing in for it.
    func testBreakEvenChipIsAlwaysPresentAndHighlighted() {
        for currentJackpot in [nil, 1_000_000, 5_900_838] as [Double?] {
            let chips = CalculatorViewModel.jackpotChips(currentJackpot: currentJackpot)
            guard let breakEvenChip = chips.first(where: { $0.id == "break-even" }) else {
                XCTFail("no break-even chip for currentJackpot \(String(describing: currentJackpot))")
                continue
            }
            XCTAssertTrue(breakEvenChip.isHighlighted)
            XCTAssertEqual(breakEvenChip.selection, .preset(EVMath.breakEvenJackpot()))
            XCTAssertFalse(chips.dropLast().contains { $0.isHighlighted }, "only the break-even chip should be highlighted")
        }
    }

    // MARK: - spendBreakdown (calculator-strategies handoff §1 waterfall)

    private let viewModel = CalculatorViewModel()

    /// System off: trivially the whole budget as $1 Ordinary combinations,
    /// regardless of size — this is the one case the toggle state alone
    /// (not `ordinaryOn`, which spendBreakdown doesn't even take) decides.
    func testSpendBreakdown_systemOff_isOrdinaryOnlyForAnyBudget() {
        for budget in [1, 7, 28, 100, 500] {
            let rows = viewModel.spendBreakdown(budget: budget, systemOn: false)
            XCTAssertEqual(rows.count, 1, "budget \(budget)")
            XCTAssertEqual(rows[0].name, "Ordinary")
            XCTAssertEqual(rows[0].count, budget)
            XCTAssertEqual(rows[0].combinations, budget)
        }
    }

    /// The four worked examples given verbatim in the design handoff —
    /// exact expected row-by-row output, not just totals, since matching
    /// the spec's own numbers precisely is the whole point.
    func testSpendBreakdown_28_matchesHandoffExample() {
        let rows = viewModel.spendBreakdown(budget: 28, systemOn: true)
        XCTAssertEqual(rows.map(\.name), ["System 8"])
        XCTAssertEqual(rows.map(\.count), [1])
        XCTAssertEqual(rows.map(\.combinations), [28])
    }

    func testSpendBreakdown_100_matchesHandoffExample() {
        let rows = viewModel.spendBreakdown(budget: 100, systemOn: true)
        XCTAssertEqual(rows.map(\.name), ["System 9", "System 7", "Ordinary"])
        XCTAssertEqual(rows.map(\.count), [1, 1, 9])
        XCTAssertEqual(rows.map(\.combinations), [84, 7, 9])
    }

    func testSpendBreakdown_250_matchesHandoffExample() {
        let rows = viewModel.spendBreakdown(budget: 250, systemOn: true)
        XCTAssertEqual(rows.map(\.name), ["System 10", "System 8", "System 7", "Ordinary"])
        XCTAssertEqual(rows.map(\.count), [1, 1, 1, 5])
        XCTAssertEqual(rows.map(\.combinations), [210, 28, 7, 5])
    }

    func testSpendBreakdown_500_matchesHandoffExample() {
        let rows = viewModel.spendBreakdown(budget: 500, systemOn: true)
        XCTAssertEqual(rows.map(\.name), ["System 10", "System 9", "System 8", "System 7", "Ordinary"])
        XCTAssertEqual(rows.map(\.count), [1, 1, 1, 1, 171])
        XCTAssertEqual(rows.map(\.combinations), [210, 84, 28, 7, 171])
    }

    /// Below System 7's $7 cost, no system tier fits at all — the whole
    /// budget falls straight through to the Ordinary mop-up, same as if
    /// System were off.
    func testSpendBreakdown_belowCheapestSystemTier_isOrdinaryOnly() {
        let rows = viewModel.spendBreakdown(budget: 5, systemOn: true)
        XCTAssertEqual(rows.map(\.name), ["Ordinary"])
        XCTAssertEqual(rows.map(\.count), [5])
    }

    /// Landing exactly on a tier's cost leaves nothing over — no trailing
    /// zero-value Ordinary row should appear.
    func testSpendBreakdown_exactTierBoundary_noOrdinaryRemainder() {
        let rows = viewModel.spendBreakdown(budget: 7, systemOn: true)
        XCTAssertEqual(rows.map(\.name), ["System 7"])
    }

    /// Each of System 10/9/8/7 can appear at most once no matter the
    /// budget — this is what bounds the breakdown to 5 rows and was the
    /// whole point of the redesign (the old per-bet-type list could grow
    /// unbounded as budget increased).
    func testSpendBreakdown_neverExceedsFiveRowsOrDuplicatesATier() {
        for budget in stride(from: 1, through: 500, by: 1) {
            let rows = viewModel.spendBreakdown(budget: budget, systemOn: true)
            XCTAssertLessThanOrEqual(rows.count, 5, "budget \(budget)")
            let names = rows.map(\.name)
            XCTAssertEqual(names.count, Set(names).count, "budget \(budget) repeated a tier: \(names)")
        }
    }

    /// Budget conservation: the breakdown must always account for the
    /// entire budget, in combinations (== dollars, since every bet type
    /// costs $1/combination) — across every budget in the app's real
    /// $1–$500 range, both with System on and off.
    func testSpendBreakdown_alwaysSumsToTheFullBudget() {
        for budget in stride(from: 1, through: 500, by: 1) {
            for systemOn in [true, false] {
                let rows = viewModel.spendBreakdown(budget: budget, systemOn: systemOn)
                let total = rows.reduce(0) { $0 + $1.combinations }
                XCTAssertEqual(total, budget, "budget \(budget) systemOn=\(systemOn)")
            }
        }
    }

    /// Waterfall order is strictly largest-tier-first when multiple tiers
    /// are present — verified independently of the specific handoff
    /// examples above, across every budget that produces 2+ rows.
    func testSpendBreakdown_systemTiersAppearLargestFirst() {
        let tierOrder = ["System 10", "System 9", "System 8", "System 7"]
        for budget in stride(from: 1, through: 500, by: 1) {
            let names = viewModel.spendBreakdown(budget: budget, systemOn: true).map(\.name)
            let presentTiersInOrder = names.filter(tierOrder.contains)
            XCTAssertEqual(presentTiersInOrder, tierOrder.filter(presentTiersInOrder.contains), "budget \(budget)")
        }
    }
}

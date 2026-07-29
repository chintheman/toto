import Foundation
import Observation

/// One row of the "What $X can buy" spend breakdown.
struct SpendBreakdownRow: Identifiable, Equatable {
    let name: String
    let count: Int
    let combinations: Int

    var id: String { name }
}

/// Which jackpot the "Value of this draw" card is currently valuing:
/// tonight's real live/estimated figure, or a preset the user tapped to
/// explore a different jackpot size hypothetically.
enum JackpotSelection: Equatable {
    case live
    case preset(Double) // dollars
}

/// One tappable chip in the jackpot-size row.
struct JackpotChip: Identifiable, Equatable {
    let id: String
    let selection: JackpotSelection
    let label: String
}

@Observable
final class CalculatorViewModel {
    private(set) var currentJackpot: Double?
    private(set) var isLoading = true
    private(set) var errorMessage: String?
    /// Defaults to live on every load — a background refresh should never
    /// silently swap out from under a jackpot size the user deliberately
    /// picked, but a fresh app launch always starts from "today's real
    /// jackpot," not whatever preset was last explored.
    private(set) var jackpotSelection: JackpotSelection = .live

    private let drawsRepository: DrawsRepository

    init(drawsRepository: DrawsRepository = DrawsRepository()) {
        self.drawsRepository = drawsRepository
    }

    func selectJackpot(_ selection: JackpotSelection) {
        jackpotSelection = selection
    }

    /// The jackpot the EV/gauge/explanation are actually valuing right now.
    var displayedJackpot: Double? {
        switch jackpotSelection {
        case .live: return currentJackpot
        case .preset(let dollars): return dollars
        }
    }

    /// True when what's on screen is a "what if this were the jackpot"
    /// example rather than tonight's real draw — must stay unmissable, since
    /// this project has a documented history of a draw being visually
    /// implied as +EV when it wasn't.
    var isShowingHypothetical: Bool {
        if case .preset = jackpotSelection { return true }
        return false
    }

    /// Today's live jackpot first (if known), then the standard presets —
    /// skipping any preset that would show the same figure as today's, so
    /// the same number never appears twice in the row.
    func jackpotChips() -> [JackpotChip] {
        Self.jackpotChips(currentJackpot: currentJackpot)
    }

    /// Pure core of `jackpotChips()`, taking the live jackpot explicitly so
    /// the dedup logic is testable without a `DrawsRepository`/network call.
    static func jackpotChips(currentJackpot: Double?) -> [JackpotChip] {
        var chips: [JackpotChip] = []
        var shownMillions: Set<Double> = []

        if let currentJackpot {
            chips.append(JackpotChip(id: "live", selection: .live, label: "Today · \(formatMillions(currentJackpot))"))
            shownMillions.insert((currentJackpot / 1_000_000 * 10).rounded() / 10)
        }

        for millions in JackpotPreset.millionsValues where !shownMillions.contains(millions) {
            let dollars = millions * 1_000_000
            chips.append(JackpotChip(id: "preset-\(millions)", selection: .preset(dollars), label: formatMillions(dollars)))
        }
        return chips
    }

    private static func formatMillions(_ dollars: Double) -> String {
        let millions = dollars / 1_000_000
        if millions == millions.rounded() {
            return "$\(Int(millions))M"
        }
        return "$\(String(format: "%.1f", millions))M"
    }

    /// "What $X can buy" spend breakdown (calculator-strategies handoff
    /// §1). Ordinary-only when System is off: trivially spends the whole
    /// budget as $1 combinations. With System on, a waterfall tries System
    /// 10 → 9 → 8 → 7 *once each*, largest first, then Ordinary always mops
    /// up whatever's left — even if the Ordinary toggle itself is off,
    /// since it's the only bet type that can spend a remainder exactly.
    /// This bounds the result at 5 rows no matter the budget, which was
    /// the whole point of replacing the old one-row-per-affordable-type
    /// list (that could show up to 5 simultaneous rows and only grew
    /// messier as budget increased).
    func spendBreakdown(budget: Int, systemOn: Bool) -> [SpendBreakdownRow] {
        guard systemOn else {
            return [SpendBreakdownRow(name: BetType.ordinary.displayName, count: budget, combinations: budget)]
        }
        var remaining = budget
        var rows: [SpendBreakdownRow] = []
        // Largest tier first, derived from BetType.cost (== C(numbersChosen,
        // 6)) rather than a second hardcoded 210/84/28/7 — EVMath.BetType is
        // the one place those numbers are allowed to live.
        let systemTiersLargestFirst: [BetType] = [.system10, .system9, .system8, .system7]
        for tier in systemTiersLargestFirst {
            let cost = Int(tier.cost)
            guard remaining >= cost else { continue }
            rows.append(SpendBreakdownRow(name: tier.displayName, count: 1, combinations: cost))
            remaining -= cost
        }
        if remaining > 0 {
            rows.append(SpendBreakdownRow(name: BetType.ordinary.displayName, count: remaining, combinations: remaining))
        }
        return rows
    }

    var ordinaryEV: Double? {
        guard let displayedJackpot else { return nil }
        return EVMath.expectedValue(betType: .ordinary, jackpot: displayedJackpot)
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
            if let jackpot = try await drawsRepository.upcomingDraw()?.estimatedJackpot {
                currentJackpot = jackpot
            } else if let latest = try await drawsRepository.latestDraw() {
                // Fallback: no upcoming-draw row yet (or its estimate isn't
                // published), estimate from the last known jackpot figure
                // rather than showing nothing.
                currentJackpot = latest.jackpotWon ? nil : latest.jackpotAmount
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

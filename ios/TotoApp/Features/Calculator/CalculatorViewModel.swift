import Foundation
import Observation

/// A "What $X can buy" row: how many of a bet type the budget affords.
struct AffordableCombo: Identifiable {
    let betType: BetType
    let count: Int
    let spend: Int

    var id: String { betType.id }
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

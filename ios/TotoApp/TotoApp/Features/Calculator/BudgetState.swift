import Foundation

/// Shared budget state used across Calculator and Picks screens.
/// Both CalculatorViewModel and PicksViewModel reference the same
/// instance so that changing the budget on either screen updates both.
@Observable
final class BudgetState {
    /// Budget value, clamped to $1–$100,000 and round to whole dollars.
    var budget: Double = 100 {
        didSet {
            let clamped = min(100_000, max(1, budget.rounded()))
            if budget != clamped { budget = clamped }
        }
    }
}

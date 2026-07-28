import Foundation
import SwiftUI

@Observable
final class AppState {
    var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: AppStorageKeys.hasCompletedOnboarding)
        }
    }

    /// App-wide play budget in SGD, shared live between Calculator and
    /// Picks (design-changes §4: one observable source; moving either
    /// updates both). Clamped to the $1–$500 range — $100,000 was never a
    /// realistic single-draw spend and made the slider nearly useless
    /// across its real, low-hundreds-of-dollars range.
    var budget: Int {
        didSet {
            let clamped = min(Self.budgetRange.upperBound, max(Self.budgetRange.lowerBound, budget))
            if clamped != budget {
                budget = clamped
                return
            }
            UserDefaults.standard.set(budget, forKey: AppStorageKeys.sharedBudget)
        }
    }

    static let budgetRange = 1...500

    init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: AppStorageKeys.hasCompletedOnboarding)
        let storedBudget = UserDefaults.standard.integer(forKey: AppStorageKeys.sharedBudget)
        budget = storedBudget == 0 ? 28 : min(Self.budgetRange.upperBound, max(Self.budgetRange.lowerBound, storedBudget))
    }
}

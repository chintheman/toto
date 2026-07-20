import Foundation

enum AppStorageKeys {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let sharedBudget = "sharedBudget"
    /// Per-number visit counts for the Numbers fun-fact rotation
    /// (design-changes §3: show facts[(visitCount − 1) % facts.count]).
    static let numberFactVisitCounts = "numberFactVisitCounts"
    static let premiumInterestEmailSaved = "premiumInterestEmailSaved"
}

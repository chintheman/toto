import Foundation
import SwiftUI

@Observable
final class AppState {
    var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: AppStorageKeys.hasCompletedOnboarding)
        }
    }

    init() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: AppStorageKeys.hasCompletedOnboarding)
    }
}

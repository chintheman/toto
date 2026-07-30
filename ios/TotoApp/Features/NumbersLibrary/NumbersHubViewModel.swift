import Foundation
import Observation

/// One number's rotation through the hero "Discover" card: which number,
/// its top fact, and a category tag to show as the pill.
struct HeroSpotlight: Equatable {
    let number: Int
    let fact: NumberFact
    let category: NumberCategory
}

@Observable
final class NumbersHubViewModel {
    private(set) var spotlight: HeroSpotlight?
    private(set) var isLoading = true
    private(set) var errorMessage: String?

    private var factsByNumber: [Int: NumberFact] = [:]
    private var rotationTask: Task<Void, Never>?
    private let factsRepository: FactsRepository
    /// Whether the Numbers tab is the one currently on screen. MainTabView
    /// keeps every tab's view (and this view model with it) alive the
    /// whole time to preserve scroll/nav state across switches — so unlike
    /// a normal SwiftUI screen, this never gets an `onDisappear`/`deinit`
    /// to stop the rotation timer on its own. `setActive` is the only
    /// thing that starts or stops it.
    private var isActive = false

    /// Categories a number can be tagged with in the hero pill, most
    /// specific/interesting first — everything falls through to even/odd,
    /// which between them cover all 49 numbers.
    private static let taggableCategories: [NumberCategory] = [
        .culturallySignificant, .fibonacci, .perfectSquares, .prime, .even, .odd
    ]

    init(factsRepository: FactsRepository = FactsRepository()) {
        self.factsRepository = factsRepository
    }

    @MainActor
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let grouped = try await factsRepository.topFacts(forNumbers: Array(1...49), limitPerNumber: 1)
            factsByNumber = grouped.compactMapValues(\.first)
            if spotlight == nil {
                advanceSpotlight()
            }
            if isActive {
                startRotationIfNeeded()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Starts or stops the rotation timer to match whether this tab is
    /// actually visible — called from `NumbersHubView` on every tab switch
    /// (via `AppState.selectedTab`), since nothing else tells this view
    /// model when it's gone off screen.
    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        if active {
            startRotationIfNeeded()
        } else {
            rotationTask?.cancel()
            rotationTask = nil
        }
    }

    /// Cycles the hero card to a new random number every few seconds.
    private func startRotationIfNeeded() {
        guard rotationTask == nil, !factsByNumber.isEmpty else { return }
        rotationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                await MainActor.run { self?.advanceSpotlight() }
            }
        }
    }

    private func advanceSpotlight() {
        guard !factsByNumber.isEmpty else { return }
        // Avoid repeating the same number twice in a row when there's more
        // than one candidate to pick from.
        var candidates = Array(factsByNumber.keys)
        if let current = spotlight?.number, candidates.count > 1 {
            candidates.removeAll { $0 == current }
        }
        guard let number = candidates.randomElement(), let fact = factsByNumber[number] else { return }
        let category = Self.taggableCategories.first { $0.numbers.contains(number) } ?? .odd
        spotlight = HeroSpotlight(number: number, fact: fact, category: category)
    }

    deinit {
        rotationTask?.cancel()
    }
}

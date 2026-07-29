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
            startRotationIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Cycles the hero card to a new random number every few seconds —
    /// stops automatically once the view (and this view model with it) is
    /// deallocated, no explicit teardown call needed.
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

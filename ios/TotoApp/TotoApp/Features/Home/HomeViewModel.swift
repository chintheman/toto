import Foundation

@Observable
final class HomeViewModel {
    private(set) var latestDraw: Draw?
    private(set) var upcomingDraw: UpcomingDraw?
    private(set) var curatedFacts: [Int: [NumberFact]] = [:] // number -> top facts
    private(set) var isLoading = true
    private(set) var errorMessage: String?

    private let drawsRepository = DrawsRepository()
    private let factsRepository = FactsRepository()

    var localNextDrawEstimate: Date {
        NextDrawSchedule.nextDrawDate()
    }

    @MainActor
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let latest = drawsRepository.latestDraw()
            async let upcoming = drawsRepository.upcomingDraw()
            latestDraw = try await latest
            upcomingDraw = try await upcoming

            if let latestDraw {
                var facts: [Int: [NumberFact]] = [:]
                for number in latestDraw.winningNumbers + [latestDraw.additionalNumber] {
                    facts[number] = try await factsRepository.topFacts(forNumber: number, limit: 2)
                }
                curatedFacts = facts
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

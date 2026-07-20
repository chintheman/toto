import Foundation

@Observable
final class HomeViewModel {
    private(set) var latestDraw: Draw?
    private(set) var upcomingDraw: UpcomingDraw?
    private(set) var curatedFacts: [Int: [NumberFact]] = [:] // number -> top facts
    private(set) var isLoading = true
    private(set) var errorMessage: String?

    // MARK: - Cache

    private(set) var lastCacheTimestamp: Date?
    private(set) var showErrorBanner = false

    var cacheAgeDescription: String? {
        guard let timestamp = lastCacheTimestamp else { return nil }
        let interval = Date().timeIntervalSince(timestamp)
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return "cached \(hours)h\(minutes > 0 ? " \(minutes)m" : "") ago"
        } else {
            return "cached \(minutes)m ago"
        }
    }

    private let drawsRepository: DrawsRepository
    private let factsRepository: FactsRepository
    private let defaults = UserDefaults.standard

    var localNextDrawEstimate: Date {
        NextDrawSchedule.nextDrawDate()
    }

    // MARK: - Cache keys

    private static let cacheKeyLatestDraw = "home_cache_latest_draw"
    private static let cacheKeyUpcomingDraw = "home_cache_upcoming_draw"
    private static let cacheKeyTimestamp = "home_cache_timestamp"

    private static let jsonEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .formatted(DateFormatter.totoDate)
        e.outputFormatting = .sortedKeys
        return e
    }()

    private static let jsonDecoder: JSONDecoder = {
        let d = JSONDecoder()
        // Draw and UpcomingDraw have custom init(from:) that parses date strings
        // using DateFormatter.totoDate, so no need to set strategy here.
        return d
    }()

    // MARK: - Init

    init(drawsRepo: DrawsRepository = DrawsRepository(), factsRepo: FactsRepository = FactsRepository()) {
        drawsRepository = drawsRepo
        factsRepository = factsRepo
        loadCache()
    }

    // MARK: - Public API

    @MainActor
    func load() async {
        isLoading = true
        errorMessage = nil
        showErrorBanner = false
        do {
            async let latest = drawsRepository.latestDraw()
            async let upcoming = drawsRepository.upcomingDraw()
            let latestResult = try await latest
            let upcomingResult = try await upcoming

            latestDraw = latestResult
            upcomingDraw = upcomingResult

            if let latestDraw {
                let numbers = latestDraw.winningNumbers + [latestDraw.additionalNumber]
                let factsDict = try await factsRepository.multiFacts(forNumbers: numbers)
                // Limit to 2 facts per number to match original topFacts behaviour
                curatedFacts = factsDict.mapValues { Array($0.prefix(2)) }
            }

            // Save to cache
            saveCache()
            lastCacheTimestamp = Date()
        } catch {
            errorMessage = error.localizedDescription
            showErrorBanner = true
            // Keep showing cached data — never clear latestDraw/upcomingDraw on failure
        }
        isLoading = false
    }

    @MainActor
    func retry() async {
        await load()
    }

    // MARK: - Cache Persistence

    private func saveCache() {
        if let draw = latestDraw,
           let data = try? Self.jsonEncoder.encode(draw) {
            defaults.set(data, forKey: Self.cacheKeyLatestDraw)
        } else {
            defaults.removeObject(forKey: Self.cacheKeyLatestDraw)
        }

        if let upcoming = upcomingDraw,
           let data = try? Self.jsonEncoder.encode(upcoming) {
            defaults.set(data, forKey: Self.cacheKeyUpcomingDraw)
        } else {
            defaults.removeObject(forKey: Self.cacheKeyUpcomingDraw)
        }

        if let timestamp = lastCacheTimestamp {
            defaults.set(timestamp.timeIntervalSinceReferenceDate, forKey: Self.cacheKeyTimestamp)
        }
    }

    private func loadCache() {
        if let data = defaults.data(forKey: Self.cacheKeyLatestDraw),
           let draw = try? Self.jsonDecoder.decode(Draw.self, from: data) {
            latestDraw = draw
        }
        if let data = defaults.data(forKey: Self.cacheKeyUpcomingDraw),
           let upcoming = try? Self.jsonDecoder.decode(UpcomingDraw.self, from: data) {
            upcomingDraw = upcoming
        }
        let interval = defaults.double(forKey: Self.cacheKeyTimestamp)
        if interval > 0 {
            lastCacheTimestamp = Date(timeIntervalSinceReferenceDate: interval)
        }
    }
}

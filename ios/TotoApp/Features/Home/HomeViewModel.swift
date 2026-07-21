import Foundation
import Observation

/// Snapshot of Home's remote data, persisted to disk so a relaunch renders
/// instantly from cache while a refresh runs in the background
/// (design-changes §2: stale-while-revalidate, never a blank screen).
struct HomeSnapshot: Codable {
    let latestDraw: Draw?
    let upcomingDraw: UpcomingDraw?
    let curatedFacts: [Int: [NumberFact]]
    let fetchedAt: Date
}

enum HomeCache {
    private static var fileURL: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("home-snapshot.json")
    }

    static func load() -> HomeSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder.supabase.decode(HomeSnapshot.self, from: data)
    }

    static func save(_ snapshot: HomeSnapshot) {
        guard let data = try? JSONEncoder.supabase.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

extension JSONDecoder {
    /// Matches supabase-swift's wire format so cached rows decode the same
    /// way they arrived.
    static let supabase: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension JSONEncoder {
    static let supabase: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

@Observable
final class HomeViewModel {
    private(set) var latestDraw: Draw?
    private(set) var upcomingDraw: UpcomingDraw?
    private(set) var curatedFacts: [Int: [NumberFact]] = [:] // number -> top facts
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    /// When the data on screen was last successfully fetched. Drives the
    /// "cached Xh ago" pill and the error banner's wording.
    private(set) var lastFetchedAt: Date?

    private let drawsRepository: DrawsRepository
    private let factsRepository: FactsRepository

    init(drawsRepository: DrawsRepository = DrawsRepository(), factsRepository: FactsRepository = FactsRepository()) {
        self.drawsRepository = drawsRepository
        self.factsRepository = factsRepository
        if let cached = HomeCache.load() {
            latestDraw = cached.latestDraw
            upcomingDraw = cached.upcomingDraw
            curatedFacts = cached.curatedFacts
            lastFetchedAt = cached.fetchedAt
        }
    }

    var isShowingStaleData: Bool {
        guard let lastFetchedAt else { return false }
        // "Stale" = the last successful fetch was over an hour ago and the
        // most recent refresh attempt failed.
        return errorMessage != nil && Date().timeIntervalSince(lastFetchedAt) > 3600
    }

    var localNextDrawEstimate: Date {
        NextDrawSchedule.nextDrawDate()
    }

    @MainActor
    func load() async {
        isLoading = true
        do {
            // Upcoming draw is best-effort and degrades independently: a
            // failure there must not discard a successfully fetched latest
            // result (the primary content).
            async let upcoming = drawsRepository.upcomingDraw()
            let fetchedLatest = try await drawsRepository.latestDraw()

            var facts: [Int: [NumberFact]] = [:]
            if let fetchedLatest {
                facts = try await factsRepository.topFacts(
                    forNumbers: fetchedLatest.winningNumbers + [fetchedLatest.additionalNumber]
                )
            }

            // Replace on success only — a failed refresh keeps showing the
            // cached data instead of blanking the screen.
            latestDraw = fetchedLatest
            curatedFacts = facts
            // Only overwrite the upcoming draw if its fetch actually
            // succeeded; on failure keep whatever was already on screen.
            if let fetchedUpcoming = try? await upcoming {
                upcomingDraw = fetchedUpcoming
            }
            lastFetchedAt = Date()
            errorMessage = nil
            HomeCache.save(HomeSnapshot(
                latestDraw: fetchedLatest,
                upcomingDraw: upcomingDraw,
                curatedFacts: facts,
                fetchedAt: lastFetchedAt ?? Date()
            ))
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

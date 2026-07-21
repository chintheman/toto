import SwiftUI

/// The Numbers grid, embedded as History's second segment
/// (design-changes §1/§3) — framed as fun facts, not statistics.
struct NumbersLibrarySection: View {
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Every number from 1 to 49 has its own fun facts. Tap one to read its story.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(1...49, id: \.self) { number in
                        NavigationLink(value: number) {
                            LotteryBallView(number: number, size: 56)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

/// Tracks how many times each number's story has been opened so the fact
/// rotates on every visit (§3: facts[(visitCount − 1) % facts.count]).
enum FactRotation {
    static func recordVisit(number: Int) -> Int {
        var counts = UserDefaults.standard.dictionary(forKey: AppStorageKeys.numberFactVisitCounts) as? [String: Int] ?? [:]
        let next = (counts[String(number)] ?? 0) + 1
        counts[String(number)] = next
        UserDefaults.standard.set(counts, forKey: AppStorageKeys.numberFactVisitCounts)
        return next
    }
}

struct NumberDetailView: View {
    let number: Int

    @State private var fact: NumberFact?
    @State private var stats: NumberStats?
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var statsFailed = false
    /// Recorded once per screen visit, so retries reuse the same rotation
    /// index instead of skipping facts.
    @State private var visitCount: Int?

    private let factsRepository: FactsRepository
    private let drawsRepository: DrawsRepository

    init(number: Int, factsRepository: FactsRepository = FactsRepository(), drawsRepository: DrawsRepository = DrawsRepository()) {
        self.number = number
        self.factsRepository = factsRepository
        self.drawsRepository = drawsRepository
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    LotteryBallView(number: number, size: 80)
                    if let fact {
                        Text(fact.headline)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        Text(fact.body)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        if let source = fact.source, !source.isEmpty {
                            Label(source, systemImage: "checkmark.seal")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                        Text("A different fact shows each visit")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else if loadFailed {
                        Text("Couldn't load this number's story")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Retry") { Task { await load() } }
                            .buttonStyle(.borderedProminent)
                    } else if !isLoading {
                        // Fetch succeeded but this number has no active facts:
                        // show an intentional empty state, not a bare ball.
                        Text("No story for this number yet. Check its stats below.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            if let stats {
                Section("\(number) in the draws") {
                    ForEach(appearanceInsights(stats)) { insight in
                        Label {
                            Text(insight.text)
                        } icon: {
                            Image(systemName: insight.symbol).foregroundStyle(Theme.ballColor(for: number))
                        }
                        .font(.subheadline)
                    }
                }
            } else if statsFailed {
                Section {
                    HStack {
                        Text("Couldn't load appearance stats").foregroundStyle(.secondary)
                        Spacer()
                        Button("Retry") { Task { await load() } }
                    }
                    .font(.subheadline)
                }
            }
        }
        .navigationTitle("Number \(number)")
        .overlay {
            if isLoading { ProgressView() }
        }
        .task { await load() }
    }

    /// Builds a VARIED set of draw-history facts: only the ones that are
    /// actually notable for this number surface, so different numbers show
    /// different mixes rather than an identical five-line template. The core
    /// count always shows; everything else is threshold-gated. Framing keeps
    /// reinforcing that any streak or drought is chance, not a signal.
    private func appearanceInsights(_ s: NumberStats) -> [AppearanceInsight] {
        var out: [AppearanceInsight] = []

        // Each draw exposes 7 numbers (6 winning + 1 additional), and
        // `appearances` counts a draw when the number is any of those 7, so
        // the expected rate is 7/49 per draw, not 6/49. Anything else labels
        // almost every number "hot", the exact fallacy this app debunks.
        let avg = Double(s.totalDraws) * 7.0 / 49.0
        let ratio = avg > 0 ? Double(s.appearances) / avg : 1
        let qualifier: String
        if ratio > 1.08 { qualifier = "a little more than pure chance predicts" }
        else if ratio < 0.92 { qualifier = "a little less than pure chance predicts" }
        else { qualifier = "right about what pure chance predicts" }
        out.append(AppearanceInsight(symbol: "chart.bar.fill",
            text: "Appeared \(s.appearances) times in \(s.totalDraws.formatted()) draws, \(qualifier)."))

        // Drought: only when it's just appeared, or the gap is genuinely long.
        if let drought = s.droughtDraws {
            if drought == 0 {
                out.append(AppearanceInsight(symbol: "checkmark.circle.fill",
                    text: "Turned up in the most recent draw."))
            } else if drought >= 8 {
                out.append(AppearanceInsight(symbol: "hourglass",
                    text: "Quiet lately: no show in the last \(drought) draws, which says nothing about the next one."))
            }
        }

        // Streak: only a genuinely eye-catching run.
        if s.longestStreak >= 3 {
            out.append(AppearanceInsight(symbol: "flame.fill",
                text: "Once hit \(s.longestStreak) draws in a row, the kind of run randomness throws up all the time."))
        }

        // Day skew: only when it actually leans one way.
        let dayTotal = s.monCount + s.thuCount
        if dayTotal > 0 {
            let diff = abs(s.monCount - s.thuCount)
            if Double(diff) / Double(dayTotal) > 0.15 {
                let leans = s.thuCount > s.monCount ? "Thursday" : "Monday"
                out.append(AppearanceInsight(symbol: "calendar.badge.clock",
                    text: "Leans \(leans) so far: \(s.thuCount) on Thursdays, \(s.monCount) on Mondays. Coincidence, not a pattern."))
            }
        }

        // Last-seen date: only when it hasn't just appeared (otherwise redundant).
        if let date = s.lastDrawDate, let num = s.lastDrawNumber, (s.droughtDraws ?? 1) > 0 {
            out.append(AppearanceInsight(symbol: "calendar",
                text: "Last seen \(date.formatted(date: .abbreviated, time: .omitted)), in Draw #\(num.formatted(.number.grouping(.never)))."))
        }

        return out
    }

    private func load() async {
        isLoading = true
        loadFailed = false
        do {
            let facts = try await factsRepository.allFacts(forNumber: number)
            if facts.isEmpty {
                fact = nil
            } else {
                let visit = visitCount ?? FactRotation.recordVisit(number: number)
                visitCount = visit
                fact = facts[(visit - 1) % facts.count]
            }
        } catch {
            loadFailed = true
        }

        // Appearance stats load independently, with their own failure state.
        do {
            async let appearances = drawsRepository.allAppearances(ofNumber: number)
            async let total = drawsRepository.totalDrawCount()
            async let latest = drawsRepository.latestDraw()
            stats = NumberStats.build(
                appearances: try await appearances,
                total: try await total,
                latest: (try await latest)?.drawNumber
            )
            statsFailed = false
        } catch {
            statsFailed = true
        }
        isLoading = false
    }
}

struct AppearanceInsight: Identifiable {
    let symbol: String
    let text: String
    var id: String { text }
}

/// Appearance statistics for a single number, computed from its draw history.
struct NumberStats {
    let appearances: Int
    let totalDraws: Int
    let lastDrawNumber: Int?
    let lastDrawDate: Date?
    let droughtDraws: Int?
    let longestStreak: Int
    let monCount: Int
    let thuCount: Int

    static func build(appearances draws: [Draw], total: Int, latest: Int?) -> NumberStats {
        let last = draws.max(by: { $0.drawNumber < $1.drawNumber })

        // Longest run of consecutive draw numbers (draw numbers are sequential).
        let ascending = draws.map(\.drawNumber).sorted()
        var longest = ascending.isEmpty ? 0 : 1
        var run = longest
        if ascending.count > 1 {
            for i in 1..<ascending.count {
                run = ascending[i] == ascending[i - 1] + 1 ? run + 1 : 1
                longest = max(longest, run)
            }
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore") ?? .current
        var mon = 0, thu = 0
        for draw in draws {
            switch calendar.component(.weekday, from: draw.drawDate) {
            case 2: mon += 1
            case 5: thu += 1
            default: break
            }
        }

        return NumberStats(
            appearances: draws.count,
            totalDraws: total,
            lastDrawNumber: last?.drawNumber,
            lastDrawDate: last?.drawDate,
            // Only report a drought when we actually know the current latest
            // draw; without it, default to no drought insight rather than a
            // misleading "appeared in the most recent draw".
            droughtDraws: latest.flatMap { current in last.map { max(0, current - $0.drawNumber) } },
            longestStreak: longest,
            monCount: mon,
            thuCount: thu
        )
    }
}

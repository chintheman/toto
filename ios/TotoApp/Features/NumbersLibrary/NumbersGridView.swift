import SwiftUI

/// The Numbers grid, embedded as History's second segment
/// (design-changes §1/§3) — framed as fun facts, not statistics.
struct NumbersLibrarySection: View {
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Every number from 1–49 has its own fun facts. Tap one to read its story.")
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
    @State private var recentDraws: [Draw] = []
    @State private var isLoading = true
    @State private var loadFailed = false

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
                        Text("A different fact shows each visit")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else if loadFailed {
                        Text("Couldn't load this number's story")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Retry") { Task { await load() } }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            if !recentDraws.isEmpty {
                Section("Recent Appearances") {
                    ForEach(recentDraws) { draw in
                        HStack {
                            Text("Draw #\(draw.drawNumber)")
                            Spacer()
                            Text(draw.drawDate, style: .date).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Number \(number)")
        .overlay {
            if isLoading { ProgressView() }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        loadFailed = false
        do {
            async let loadedFacts = factsRepository.allFacts(forNumber: number)
            async let loadedDraws = drawsRepository.draws(containingNumber: number)
            let facts = try await loadedFacts
            recentDraws = (try? await loadedDraws) ?? []
            if facts.isEmpty {
                fact = nil
                loadFailed = false
            } else {
                let visitCount = FactRotation.recordVisit(number: number)
                fact = facts[(visitCount - 1) % facts.count]
            }
        } catch {
            loadFailed = true
        }
        isLoading = false
    }
}

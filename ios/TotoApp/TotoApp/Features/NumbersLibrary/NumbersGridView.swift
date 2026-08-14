import SwiftUI

struct NumberDetailView: View {
    let number: Int

    @State private var facts: [NumberFact] = []
    @State private var recentDraws: [Draw] = []
    @State private var isLoading = true

    private let factsRepository = FactsRepository()
    private let drawsRepository = DrawsRepository()

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    LotteryBallView(number: number, size: 80)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section("Facts") {
                ForEach(facts) { fact in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(fact.headline).font(.subheadline.bold())
                        Text(fact.body).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
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
        .task {
            async let loadedFacts = factsRepository.allFacts(forNumber: number)
            async let loadedDraws = drawsRepository.draws(containingNumber: number)
            facts = (try? await loadedFacts) ?? []
            recentDraws = (try? await loadedDraws) ?? []
            isLoading = false
        }
    }
}

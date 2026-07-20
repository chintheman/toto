import SwiftUI

struct HistoryView: View {
    @State private var viewModel = HistoryViewModel()
    @State private var selectedSegment = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $selectedSegment) {
                    Text("Draws").tag(0)
                    Text("Numbers").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if selectedSegment == 0 {
                    drawsList
                } else {
                    numbersGrid
                }
            }
            .navigationTitle("History")
            .task { await viewModel.loadInitial() }
        }
    }

    private var drawsList: some View {
        List(viewModel.draws) { draw in
            NavigationLink(value: draw) {
                DrawRow(draw: draw)
            }
            .task { await viewModel.loadMoreIfNeeded(currentItem: draw) }
        }
        .listStyle(.plain)
        .navigationDestination(for: Draw.self) { draw in
            DrawDetailView(draw: draw)
        }
        .overlay {
            if viewModel.isLoading && viewModel.draws.isEmpty {
                ProgressView()
            } else if viewModel.draws.isEmpty, let error = viewModel.errorMessage {
                ContentUnavailableView("Couldn't load history", systemImage: "wifi.slash", description: Text(error))
            }
        }
        .refreshable { await viewModel.refresh() }
    }

    private var numbersGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text("Every number from 1–49 has its own fun facts. Tap one to read its story.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5),
                spacing: 12
            ) {
                ForEach(1...49, id: \.self) { number in
                    NavigationLink(value: number) {
                        LotteryBallView(number: number, size: 56)
                    }
                }
            }
            .padding()
        }
        .navigationDestination(for: Int.self) { number in
            NumberFactDetail(number: number)
        }
    }
}

// MARK: - Draw Row

private struct DrawRow: View {
    let draw: Draw

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Draw #\(draw.drawNumber)").font(.subheadline.bold())
                Text(draw.drawDate, style: .date).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 4) {
                ForEach(draw.winningNumbers, id: \.self) { number in
                    LotteryBallView(number: number, size: 26)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Number Fact Detail

struct NumberFactDetail: View {
    let number: Int

    @State private var currentFact: NumberFact?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let repository = FactsRepository()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            LotteryBallView(number: number, size: 100)

            if let error = errorMessage {
                ContentUnavailableView(
                    "Couldn't load facts",
                    systemImage: "wifi.slash",
                    description: Text(error)
                )
                Button("Retry") {
                    Task { await loadFacts() }
                }
                .buttonStyle(.borderedProminent)
            } else if isLoading {
                ProgressView()
            } else if let fact = currentFact {
                VStack(alignment: .leading, spacing: 8) {
                    Text(fact.headline)
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                    Text(fact.body)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                Text("A different fact shows each visit")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .navigationTitle("Number \(number)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadFacts()
        }
    }

    @MainActor
    private func loadFacts() async {
        isLoading = true
        errorMessage = nil
        do {
            let loadedFacts = try await repository.allFacts(forNumber: number)
            if !loadedFacts.isEmpty {
                let key = "numberFactVisit_\(number)"
                let visitCount = UserDefaults.standard.integer(forKey: key) + 1
                UserDefaults.standard.set(visitCount, forKey: key)
                currentFact = loadedFacts[(visitCount - 1) % loadedFacts.count]
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Draw Detail

struct DrawDetailView: View {
    let draw: Draw
    @State private var prizeGroups: [PrizeGroup] = []
    @State private var errorMessage: String?
    private let repository = DrawsRepository()

    var body: some View {
        List {
            Section("Winning Numbers") {
                HStack(spacing: 8) {
                    ForEach(draw.winningNumbers, id: \.self) { LotteryBallView(number: $0, size: 40) }
                    LotteryBallView(number: draw.additionalNumber, size: 40, isAdditional: true)
                }
                .padding(.vertical, 4)
            }

            if let error = errorMessage {
                Section {
                    HStack {
                        Image(systemName: "wifi.slash")
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Couldn't load prize breakdown")
                                .font(.subheadline.bold())
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Retry") {
                            Task { await loadPrizeGroups() }
                        }
                        .font(.subheadline.bold())
                    }
                }
            } else {
                Section("Prize Breakdown") {
                    ForEach(prizeGroups) { group in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Group \(group.groupNumber)")
                                if group.groupNumber == 1 {
                                    Text(draw.jackpotWon ? "Jackpot won" : "Jackpot rolled over")
                                        .font(.caption)
                                        .foregroundStyle(draw.jackpotWon ? .green : .orange)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(group.prizePerWinner, format: .currency(code: "SGD"))
                                Text("\(group.winnerCount) winner\(group.winnerCount == 1 ? "" : "s")")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }

                Section {
                    Link("View original source", destination: URL(string: draw.sourceUrl) ?? URL(string: "https://singaporepools.com.sg")!)
                }
            }
        }
        .navigationTitle("Draw #\(draw.drawNumber)")
        .task {
            await loadPrizeGroups()
        }
    }

    @MainActor
    private func loadPrizeGroups() async {
        errorMessage = nil
        do {
            prizeGroups = try await repository.prizeGroups(forDrawId: draw.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

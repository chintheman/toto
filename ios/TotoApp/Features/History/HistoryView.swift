import SwiftUI

/// Design-changes §1/§3: History hosts a `Draws | Numbers` segmented
/// control — the old Numbers tab folds in here, framed as fun facts.
struct HistoryView: View {
    private enum Segment: String, CaseIterable, Identifiable {
        case draws = "Draws"
        case numbers = "Numbers"
        var id: String { rawValue }
    }

    @State private var viewModel = HistoryViewModel()
    @State private var segment: Segment = .draws

    var body: some View {
        NavigationStack {
            Group {
                switch segment {
                case .draws: drawsList
                case .numbers: NumbersLibrarySection()
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Section", selection: $segment) {
                        ForEach(Segment.allCases) { segment in
                            Text(segment.rawValue).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                }
            }
            .navigationDestination(for: Draw.self) { draw in
                DrawDetailView(draw: draw)
            }
            .navigationDestination(for: Int.self) { number in
                NumberDetailView(number: number)
            }
        }
    }

    private var drawsList: some View {
        List(viewModel.draws) { draw in
            NavigationLink(value: draw) {
                DrawRow(draw: draw)
            }
            .task { await viewModel.loadMoreIfNeeded(currentItem: draw) }
        }
        .overlay {
            if viewModel.isLoading && viewModel.draws.isEmpty {
                ProgressView()
            } else if viewModel.draws.isEmpty, let error = viewModel.errorMessage {
                ContentUnavailableView {
                    Label("Couldn't load history", systemImage: "wifi.slash")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { Task { await viewModel.loadInitial() } }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .refreshable { await viewModel.refresh() }
        .task { await viewModel.loadInitial() }
    }
}

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

struct DrawDetailView: View {
    let draw: Draw

    @State private var prizeGroups: [PrizeGroup] = []
    @State private var prizeLoadFailed = false
    private let repository: DrawsRepository

    init(draw: Draw, repository: DrawsRepository = DrawsRepository()) {
        self.draw = draw
        self.repository = repository
    }

    var body: some View {
        List {
            Section("Winning Numbers") {
                HStack(spacing: 8) {
                    ForEach(draw.winningNumbers, id: \.self) { LotteryBallView(number: $0, size: 40) }
                    Text("+").foregroundStyle(.secondary)
                    LotteryBallView(number: draw.additionalNumber, size: 40, isAdditional: true)
                }
                .padding(.vertical, 4)
            }

            Section("Prize Breakdown") {
                HStack {
                    Text("Jackpot (Group 1)")
                    Spacer()
                    if draw.jackpotWon {
                        Text(draw.jackpotAmount, format: .currency(code: "SGD").precision(.fractionLength(0)))
                    } else {
                        Text("\(draw.jackpotAmount, format: .currency(code: "SGD").precision(.fractionLength(0))) — rolled over")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.subheadline)

                if prizeLoadFailed {
                    // §7: no silent try? swallowing — failed loads get a
                    // visible state and a retry.
                    HStack {
                        Text("Couldn't load prize groups").foregroundStyle(.secondary)
                        Spacer()
                        Button("Retry") { Task { await loadPrizeGroups() } }
                    }
                    .font(.subheadline)
                } else {
                    ForEach(prizeGroups.filter { $0.groupNumber > 1 }) { group in
                        HStack {
                            Text(groupLabel(group.groupNumber))
                            Spacer()
                            Text(group.prizePerWinner, format: .currency(code: "SGD"))
                            Text("· \(group.winnerCount) winner\(group.winnerCount == 1 ? "" : "s")")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .font(.subheadline)
                    }
                }
            }

            Section {
                Link("View original source", destination: URL(string: draw.sourceUrl) ?? URL(string: "https://singaporepools.com.sg")!)
            }
        }
        .navigationTitle("Draw #\(draw.drawNumber)")
        .task { await loadPrizeGroups() }
    }

    private func groupLabel(_ groupNumber: Int) -> String {
        switch groupNumber {
        case 2: return "Group 2 (5 + additional)"
        case 3: return "Group 3 (5 numbers)"
        case 4: return "Group 4 (4 + additional)"
        case 5: return "Group 5 (4 numbers)"
        case 6: return "Group 6 (3 + additional)"
        case 7: return "Group 7 (3 numbers)"
        default: return "Group \(groupNumber)"
        }
    }

    private func loadPrizeGroups() async {
        do {
            prizeGroups = try await repository.prizeGroups(forDrawId: draw.id)
            prizeLoadFailed = false
        } catch {
            prizeLoadFailed = true
        }
    }
}

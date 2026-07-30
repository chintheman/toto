import SwiftUI

/// Design iteration 1.1.0: History is Draws-only now — Numbers has its
/// own standalone hub/reel tab (`NumbersHubView`), so the old
/// Draws|Numbers segmented control is gone.
struct HistoryView: View {
    @State private var viewModel = HistoryViewModel()

    var body: some View {
        NavigationStack {
            drawsList
                .navigationTitle("History")
                .navigationDestination(for: Draw.self) { draw in
                    DrawDetailView(draw: draw)
                }
        }
    }

    private var drawsList: some View {
        List {
            if viewModel.errorMessage != nil && !viewModel.draws.isEmpty {
                // Failed refresh with rows still on screen: quiet inline
                // notice instead of silently showing stale data.
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("Couldn't refresh. Showing earlier results.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Retry") { Task { await viewModel.refresh() } }
                        .font(.caption.bold())
                }
                .listRowBackground(Color.orange.opacity(0.1))
            }
            Section("Draw History") {
                ForEach(viewModel.draws) { draw in
                    NavigationLink(value: draw) {
                        DrawRow(draw: draw)
                    }
                    .task { await viewModel.loadMoreIfNeeded(currentItem: draw) }
                }
            }
        }
        .floatingNavBarClearance()
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
            } else if viewModel.draws.isEmpty && !viewModel.isLoading {
                // Loaded successfully but no rows: an intentional empty state
                // instead of a blank list.
                ContentUnavailableView(
                    "No draws yet",
                    systemImage: "calendar",
                    description: Text("Results will appear here after the next draw.")
                )
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
                // The section header above already reads "Draw History" —
                // repeating "Draw" on every single row was redundant and,
                // at larger text sizes, wrapped onto two lines and squeezed
                // the number balls.
                Text("#\(draw.drawNumber, format: .number.grouping(.never))").font(.title3.bold())
                Text(draw.drawDate, style: .date).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 4) {
                ForEach(draw.winningNumbers, id: \.self) { number in
                    LotteryBallView(number: number, size: 28)
                }
            }
        }
        .padding(.vertical, 6)
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
                        Text("\(draw.jackpotAmount, format: .currency(code: "SGD").precision(.fractionLength(0))) won")
                            .foregroundStyle(.green)
                    } else {
                        Text("\(draw.jackpotAmount, format: .currency(code: "SGD").precision(.fractionLength(0))), rolled over")
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
                            Text(group.prizePerWinner, format: .currency(code: "SGD").precision(.fractionLength(0)))
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
        .floatingNavBarClearance()
        .navigationTitle("Draw #\(draw.drawNumber, format: .number.grouping(.never))")
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

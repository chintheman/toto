import SwiftUI

struct HistoryView: View {
    @State private var viewModel = HistoryViewModel()

    var body: some View {
        NavigationStack {
            List(viewModel.draws) { draw in
                NavigationLink(value: draw) {
                    DrawRow(draw: draw)
                }
                .task { await viewModel.loadMoreIfNeeded(currentItem: draw) }
            }
            .navigationTitle("History")
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
            .task { await viewModel.loadInitial() }
        }
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

            Section("Prize Breakdown") {
                ForEach(prizeGroups) { group in
                    HStack {
                        Text("Group \(group.groupNumber)")
                        Spacer()
                        Text(group.prizePerWinner, format: .currency(code: "SGD"))
                        Text("· \(group.winnerCount) winner\(group.winnerCount == 1 ? "" : "s")")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }

            Section {
                Link("View original source", destination: URL(string: draw.sourceUrl) ?? URL(string: "https://singaporepools.com.sg")!)
            }
        }
        .navigationTitle("Draw #\(draw.drawNumber)")
        .task {
            prizeGroups = (try? await repository.prizeGroups(forDrawId: draw.id)) ?? []
        }
    }
}

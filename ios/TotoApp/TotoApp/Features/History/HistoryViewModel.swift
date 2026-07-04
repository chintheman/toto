import Foundation

@Observable
final class HistoryViewModel {
    private(set) var draws: [Draw] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var reachedEnd = false

    private let repository = DrawsRepository()
    private let pageSize = 30

    @MainActor
    func loadInitial() async {
        guard draws.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            draws = try await repository.history(limit: pageSize)
            reachedEnd = draws.count < pageSize
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    func loadMoreIfNeeded(currentItem draw: Draw) async {
        guard draw.id == draws.last?.id, !isLoading, !reachedEnd else { return }
        isLoading = true
        do {
            let more = try await repository.history(limit: pageSize, before: draw.drawNumber)
            draws.append(contentsOf: more)
            reachedEnd = more.count < pageSize
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    func refresh() async {
        draws = []
        reachedEnd = false
        await loadInitial()
    }
}

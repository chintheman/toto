import Foundation

@Observable
final class HistoryViewModel {
    private(set) var draws: [Draw] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var reachedEnd = false

    private let repository: DrawsRepository
    private let pageSize = 30

    init(repository: DrawsRepository = DrawsRepository()) {
        self.repository = repository
    }

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

    /// Design-changes §3: refresh must NOT clear the list before fetching —
    /// the existing rows stay on screen and are replaced only on success.
    @MainActor
    func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            let fresh = try await repository.history(limit: pageSize)
            draws = fresh
            reachedEnd = fresh.count < pageSize
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

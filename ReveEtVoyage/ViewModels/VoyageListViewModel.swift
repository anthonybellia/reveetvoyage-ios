import Foundation

@MainActor
final class VoyageListViewModel: ObservableObject {
    @Published var voyages: [Voyage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var canLoadMore = true

    private let voyageService = VoyageService.shared
    private var currentPage = 1
    private let perPage = 20

    func loadVoyages() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let (items, hasMore) = try await voyageService.getVoyages(page: 1, perPage: perPage)
            voyages = items
            canLoadMore = hasMore
            currentPage = 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore() async {
        guard canLoadMore, !isLoading else { return }

        isLoading = true
        currentPage += 1
        defer { isLoading = false }

        do {
            let (items, hasMore) = try await voyageService.getVoyages(page: currentPage, perPage: perPage)
            voyages.append(contentsOf: items)
            canLoadMore = hasMore && !items.isEmpty
        } catch {
            errorMessage = error.localizedDescription
            currentPage -= 1
        }
    }

    func refresh() async {
        currentPage = 1
        canLoadMore = true
        await loadVoyages()
    }
}

import Foundation

@MainActor
final class DevisListViewModel: ObservableObject {
    @Published var devis: [Devis] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var canLoadMore = true

    private let service = DevisService.shared
    private var currentPage = 1
    private let perPage = 20

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let (items, hasMore) = try await service.getDevis(page: 1, perPage: perPage)
            devis = items
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
            let (items, hasMore) = try await service.getDevis(page: currentPage, perPage: perPage)
            devis.append(contentsOf: items)
            canLoadMore = hasMore && !items.isEmpty
        } catch {
            errorMessage = error.localizedDescription
            currentPage -= 1
        }
    }

    func refresh() async {
        currentPage = 1
        canLoadMore = true
        await load()
    }

    var pending: [Devis] { devis.filter { $0.statut == "nouveau" || $0.statut == "en_cours" } }
    var validated: [Devis] { devis.filter { $0.statut == "valide" } }
    var others: [Devis] { devis.filter { ["refuse", "archive"].contains($0.statut) } }
}

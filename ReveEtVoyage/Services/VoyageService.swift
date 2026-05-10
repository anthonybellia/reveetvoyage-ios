import Foundation

@MainActor
final class VoyageService: ObservableObject {
    static let shared = VoyageService()

    @Published var voyages: [Voyage] = []
    @Published var currentVoyage: Voyage?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var hasMorePages: Bool = false

    private let apiClient = APIClient.shared
    private(set) var currentPage: Int = 1
    private let perPage: Int = 20

    private init() {}

    // MARK: - List

    func fetchVoyages(page: Int = 1) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: APIResponse<[Voyage]> = try await apiClient.get(
                path: APIConfig.Endpoints.voyages,
                queryParams: [
                    "page": String(page),
                    "per_page": String(perPage)
                ],
                requiresAuth: true
            )
            if let data = response.data {
                if page == 1 {
                    voyages = data
                } else {
                    voyages.append(contentsOf: data)
                }
                currentPage = page
                // Simplified pagination check (Phase 3 limitation, real metadata in Phase 4)
                hasMorePages = (page * perPage) < 1000
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadNextPage() async {
        guard hasMorePages, !isLoading else { return }
        await fetchVoyages(page: currentPage + 1)
    }

    func refresh() async {
        await fetchVoyages(page: 1)
    }

    // MARK: - Detail

    func fetchVoyage(token: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: APIResponse<Voyage> = try await apiClient.get(
                path: "\(APIConfig.Endpoints.voyages)/\(token)",
                requiresAuth: true
            )
            currentVoyage = response.data
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Etape completion

    func markEtapeCompleted(voyageToken: String, etapeId: Int) async -> Bool {
        do {
            try await apiClient.postVoid(
                path: "\(APIConfig.Endpoints.voyages)/\(voyageToken)/etapes/\(etapeId)/complete",
                requiresAuth: true
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func markEtapeIncomplete(voyageToken: String, etapeId: Int) async -> Bool {
        do {
            try await apiClient.deleteVoid(
                path: "\(APIConfig.Endpoints.voyages)/\(voyageToken)/etapes/\(etapeId)/complete",
                requiresAuth: true
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

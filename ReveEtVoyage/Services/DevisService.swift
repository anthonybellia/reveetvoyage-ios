import Foundation

@MainActor
final class DevisService: ObservableObject {
    static let shared = DevisService()

    @Published var devisList: [Devis] = []
    @Published var currentDevis: Devis?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var hasMorePages: Bool = false

    private let apiClient = APIClient.shared
    private(set) var currentPage: Int = 1
    private let perPage: Int = 20

    private init() {}

    // MARK: - List

    func fetchDevis(page: Int = 1) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: APIResponse<[Devis]> = try await apiClient.get(
                path: APIConfig.Endpoints.devis,
                queryParams: [
                    "page": String(page),
                    "per_page": String(perPage)
                ],
                requiresAuth: true
            )
            if let data = response.data {
                if page == 1 {
                    devisList = data
                } else {
                    devisList.append(contentsOf: data)
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
        await fetchDevis(page: currentPage + 1)
    }

    func refresh() async {
        await fetchDevis(page: 1)
    }

    // MARK: - Detail

    func fetchDevis(token: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: APIResponse<Devis> = try await apiClient.get(
                path: "\(APIConfig.Endpoints.devis)/\(token)",
                requiresAuth: true
            )
            currentDevis = response.data
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Create

    func createDevis(_ request: DevisCreateRequest) async -> Devis? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: APIResponse<Devis> = try await apiClient.post(
                path: APIConfig.Endpoints.devis,
                body: request,
                requiresAuth: true
            )
            if let devis = response.data {
                devisList.insert(devis, at: 0)
                return devis
            }
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

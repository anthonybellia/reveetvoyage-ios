import Foundation

@MainActor
final class OffreService: ObservableObject {
    static let shared = OffreService()

    @Published var offres: [Offre] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let apiClient = APIClient.shared

    private init() {}

    // MARK: - List (public, no auth required)

    func fetchOffres() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: APIResponse<[Offre]> = try await apiClient.get(
                path: APIConfig.Endpoints.offres,
                requiresAuth: false
            )
            if let data = response.data {
                offres = data.sorted { $0.order < $1.order }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        await fetchOffres()
    }
}

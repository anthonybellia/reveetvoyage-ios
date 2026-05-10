import Foundation

final class DevisService {
    static let shared = DevisService()
    private let apiClient = APIClient.shared

    private init() {}

    func getDevis(page: Int = 1, perPage: Int = 20) async throws -> ([Devis], Bool) {
        let queryParams = ["page": String(page), "per_page": String(perPage)]
        let response: APIResponse<[Devis]> = try await apiClient.get(
            path: APIConfig.Endpoints.devis,
            queryParams: queryParams,
            requiresAuth: true
        )
        let items = response.data ?? []
        let hasMore = items.count == perPage
        return (items, hasMore)
    }

    func getDevisDetail(id: Int) async throws -> Devis {
        let response: APIResponse<Devis> = try await apiClient.get(
            path: "\(APIConfig.Endpoints.devis)/\(id)",
            requiresAuth: true
        )
        guard let devis = response.data else {
            throw NetworkError.serverError(statusCode: 404, message: "Devis not found")
        }
        return devis
    }

    func createDevis(request: DevisCreateRequest) async throws -> Devis {
        let response: APIResponse<Devis> = try await apiClient.post(
            path: APIConfig.Endpoints.devis,
            body: request,
            requiresAuth: true
        )
        guard let devis = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Failed to create devis")
        }
        return devis
    }
}

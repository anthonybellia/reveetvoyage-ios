import Foundation

final class VoyageService {
    static let shared = VoyageService()
    private let apiClient = APIClient.shared

    private init() {}

    func getVoyages(page: Int = 1, perPage: Int = 20) async throws -> ([Voyage], Bool) {
        let queryParams = ["page": String(page), "per_page": String(perPage)]
        let response: APIResponse<[Voyage]> = try await apiClient.get(
            path: APIConfig.Endpoints.voyages,
            queryParams: queryParams,
            requiresAuth: true
        )
        let items = response.data ?? []
        // Phase 3 simplified pagination — Phase 4 will read meta.last_page from APIResponse
        let hasMore = items.count == perPage
        return (items, hasMore)
    }

    func getVoyageDetail(id: Int) async throws -> Voyage {
        let response: APIResponse<Voyage> = try await apiClient.get(
            path: "\(APIConfig.Endpoints.voyages)/\(id)",
            requiresAuth: true
        )
        guard let voyage = response.data else {
            throw NetworkError.serverError(statusCode: 404, message: "Voyage not found")
        }
        return voyage
    }
}

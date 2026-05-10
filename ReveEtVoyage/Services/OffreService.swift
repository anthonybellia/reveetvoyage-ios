import Foundation

final class OffreService {
    static let shared = OffreService()
    private let apiClient = APIClient.shared

    private init() {}

    func getOffres() async throws -> [Offre] {
        let response: APIResponse<[Offre]> = try await apiClient.get(
            path: APIConfig.Endpoints.offres,
            requiresAuth: false
        )
        return (response.data ?? []).sorted { $0.order < $1.order }
    }

    func getOffreDetail(id: Int) async throws -> Offre {
        let response: APIResponse<Offre> = try await apiClient.get(
            path: "\(APIConfig.Endpoints.offres)/\(id)",
            requiresAuth: false
        )
        guard let offre = response.data else {
            throw NetworkError.serverError(statusCode: 404, message: "Offre not found")
        }
        return offre
    }
}

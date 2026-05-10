import Foundation

final class PassengerService {
    static let shared = PassengerService()
    private let apiClient = APIClient.shared

    private init() {}

    func getPassengers() async throws -> [Passenger] {
        let response: APIResponse<[Passenger]> = try await apiClient.get(
            path: APIConfig.Endpoints.passengers,
            requiresAuth: true
        )
        return response.data ?? []
    }

    func getPassengerDetail(id: Int) async throws -> Passenger {
        let response: APIResponse<Passenger> = try await apiClient.get(
            path: "\(APIConfig.Endpoints.passengers)/\(id)",
            requiresAuth: true
        )
        guard let passenger = response.data else {
            throw NetworkError.serverError(statusCode: 404, message: "Passenger not found")
        }
        return passenger
    }

    func createPassenger(request: PassengerCreateRequest) async throws -> Passenger {
        let response: APIResponse<Passenger> = try await apiClient.post(
            path: APIConfig.Endpoints.passengers,
            body: request,
            requiresAuth: true
        )
        guard let passenger = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Failed to create passenger")
        }
        return passenger
    }

    func updatePassenger(id: Int, request: PassengerUpdateRequest) async throws -> Passenger {
        let response: APIResponse<Passenger> = try await apiClient.put(
            path: "\(APIConfig.Endpoints.passengers)/\(id)",
            body: request,
            requiresAuth: true
        )
        guard let passenger = response.data else {
            throw NetworkError.serverError(statusCode: 500, message: "Failed to update passenger")
        }
        return passenger
    }

    func deletePassenger(id: Int) async throws {
        try await apiClient.deleteVoid(
            path: "\(APIConfig.Endpoints.passengers)/\(id)",
            requiresAuth: true
        )
    }
}

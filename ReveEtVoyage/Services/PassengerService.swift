import Foundation

@MainActor
final class PassengerService: ObservableObject {
    static let shared = PassengerService()

    @Published var passengers: [Passenger] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let apiClient = APIClient.shared

    private init() {}

    // MARK: - List

    func fetchPassengers() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: APIResponse<[Passenger]> = try await apiClient.get(
                path: APIConfig.Endpoints.passengers,
                requiresAuth: true
            )
            if let data = response.data {
                passengers = data
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        await fetchPassengers()
    }

    // MARK: - Create

    func createPassenger(_ request: PassengerCreateRequest) async -> Passenger? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: APIResponse<Passenger> = try await apiClient.post(
                path: APIConfig.Endpoints.passengers,
                body: request,
                requiresAuth: true
            )
            if let passenger = response.data {
                passengers.append(passenger)
                return passenger
            }
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Update

    func updatePassenger(id: Int, _ request: PassengerUpdateRequest) async -> Passenger? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response: APIResponse<Passenger> = try await apiClient.put(
                path: "\(APIConfig.Endpoints.passengers)/\(id)",
                body: request,
                requiresAuth: true
            )
            if let updated = response.data {
                if let idx = passengers.firstIndex(where: { $0.id == id }) {
                    passengers[idx] = updated
                }
                return updated
            }
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Delete

    func deletePassenger(id: Int) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await apiClient.deleteVoid(
                path: "\(APIConfig.Endpoints.passengers)/\(id)",
                requiresAuth: true
            )
            passengers.removeAll { $0.id == id }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

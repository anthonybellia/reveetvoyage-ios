import Foundation

final class AirportService {
    static let shared = AirportService()
    private let apiClient = APIClient.shared

    private init() {}

    func search(query: String) async throws -> [Airport] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return [] }
        return try await apiClient.get(
            path: "/airports",
            queryParams: ["q": trimmed],
            requiresAuth: false
        )
    }
}

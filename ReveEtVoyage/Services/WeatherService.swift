import Foundation

// MARK: - Models matching backend /api/weather

struct WeatherResponse: Decodable {
    let timezone: String?
    let current: WeatherCurrent?
    let forecast: [WeatherDay]
}

struct WeatherCurrent: Decodable {
    let temp: Double?
    let feels_like: Double?
    let code: Int?
    let wind: Double?
    let humidity: Double?
    let is_day: Bool?
}

struct WeatherDay: Decodable, Identifiable {
    var id: String { date }
    let date: String
    let temp_max: Double?
    let temp_min: Double?
    let code: Int?
    let precip_prob: Int?
}

// MARK: - Service

@MainActor
final class WeatherService: ObservableObject {
    static let shared = WeatherService()

    private let apiClient = APIClient.shared
    private init() {}

    func fetch(latitude: Double, longitude: Double) async throws -> WeatherResponse {
        try await apiClient.get(
            path: APIConfig.Endpoints.weather,
            queryParams: [
                "lat": String(latitude),
                "lng": String(longitude),
            ],
            requiresAuth: true,
        )
    }
}

import Foundation

final class APIClient {
    static let shared = APIClient()

    private var token: String? {
        get { KeychainHelper.shared.getToken() }
    }

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfig.requestTimeout
        config.timeoutIntervalForResource = APIConfig.resourceTimeout
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    private lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            // ISO 8601 with fractional seconds
            let isoWithFraction = ISO8601DateFormatter()
            isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoWithFraction.date(from: string) { return date }

            // ISO 8601 without fractional seconds
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: string) { return date }

            // Laravel default: "yyyy-MM-dd HH:mm:ss"
            let dateTimeFmt = DateFormatter()
            dateTimeFmt.locale = Locale(identifier: "en_US_POSIX")
            dateTimeFmt.timeZone = TimeZone(identifier: "UTC")
            dateTimeFmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
            if let date = dateTimeFmt.date(from: string) { return date }

            // Date-only: "yyyy-MM-dd"
            let dateOnlyFmt = DateFormatter()
            dateOnlyFmt.locale = Locale(identifier: "en_US_POSIX")
            dateOnlyFmt.timeZone = TimeZone(identifier: "UTC")
            dateOnlyFmt.dateFormat = "yyyy-MM-dd"
            if let date = dateOnlyFmt.date(from: string) { return date }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unparseable date: \(string)"
            )
        }
        return decoder
    }()

    private init() {}

    // MARK: - Token state

    func setToken(_ newToken: String) {
        KeychainHelper.shared.saveToken(newToken)
    }

    func clearToken() {
        KeychainHelper.shared.deleteToken()
    }

    func isAuthenticated() -> Bool {
        return token != nil
    }

    // MARK: - Generic request

    func request<T: Decodable>(
        method: String,
        path: String,
        queryParams: [String: String]? = nil,
        body: (any Encodable)? = nil,
        requiresAuth: Bool = false
    ) async throws -> T {
        guard var components = URLComponents(url: APIConfig.baseURL, resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidURL
        }
        components.path += path
        if let queryParams = queryParams {
            components.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ios", forHTTPHeaderField: "X-Client-Platform")
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            request.setValue("ReveEtVoyage-iOS/\(appVersion)", forHTTPHeaderField: "User-Agent")
        }

        if requiresAuth {
            guard let token = self.token else {
                throw NetworkError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NetworkError.requestFailed(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(NSError(domain: "InvalidResponse", code: -1))
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw NetworkError.decodingFailed(error)
            }

        case 401:
            clearToken()
            throw NetworkError.unauthorized

        case 422:
            if let apiError = try? decoder.decode(APIError.self, from: data),
               let errors = apiError.errors {
                throw NetworkError.validationError(errors)
            }
            throw NetworkError.serverError(statusCode: 422, message: "Validation error")

        default:
            let apiError = try? decoder.decode(APIError.self, from: data)
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, message: apiError?.message)
        }
    }

    // MARK: - Convenience

    func get<T: Decodable>(
        path: String,
        queryParams: [String: String]? = nil,
        requiresAuth: Bool = false
    ) async throws -> T {
        try await request(method: "GET", path: path, queryParams: queryParams, requiresAuth: requiresAuth)
    }

    func post<T: Decodable>(
        path: String,
        body: (any Encodable)? = nil,
        requiresAuth: Bool = false
    ) async throws -> T {
        try await request(method: "POST", path: path, body: body, requiresAuth: requiresAuth)
    }

    func put<T: Decodable>(
        path: String,
        body: (any Encodable)? = nil,
        requiresAuth: Bool = false
    ) async throws -> T {
        try await request(method: "PUT", path: path, body: body, requiresAuth: requiresAuth)
    }

    func delete<T: Decodable>(
        path: String,
        requiresAuth: Bool = false
    ) async throws -> T {
        try await request(method: "DELETE", path: path, requiresAuth: requiresAuth)
    }

    func postVoid(
        path: String,
        body: (any Encodable)? = nil,
        requiresAuth: Bool = false
    ) async throws {
        let _: VoidResponse = try await request(method: "POST", path: path, body: body, requiresAuth: requiresAuth)
    }

    func deleteVoid(
        path: String,
        requiresAuth: Bool = false
    ) async throws {
        let _: VoidResponse = try await request(method: "DELETE", path: path, requiresAuth: requiresAuth)
    }
}

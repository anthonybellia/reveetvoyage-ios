import Foundation
import CryptoKit

final class APIClient {
    static let shared = APIClient()

    private var token: String? {
        get { KeychainHelper.shared.getToken() }
    }

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfig.requestTimeout
        config.timeoutIntervalForResource = APIConfig.resourceTimeout
        // Hors-ligne : échouer immédiatement plutôt que d'attendre la connectivité
        // (sinon login/GET « bloquent » jusqu'à 60s). Sur un GET, l'échec déclenche
        // le repli sur le cache disque ; sur le login, une erreur claire est affichée.
        config.waitsForConnectivity = false
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

    // MARK: - Auth headers (point d'injection unique)

    /// Pose le Bearer token et, le cas échéant, l'en-tête `X-Preview-As-User: 1`.
    /// Point UNIQUE d'injection des en-têtes d'authentification : appelé par toutes
    /// les constructions d'`URLRequest` authentifiées (requêtes JSON + multipart).
    /// L'en-tête d'aperçu n'est ajouté que pour un vrai admin en mode aperçu client
    /// (`PreviewState.shouldSendPreviewHeader`) et jamais sur une requête anonyme.
    private func applyAuthHeaders(to request: inout URLRequest) throws {
        guard let token = self.token else {
            throw NetworkError.unauthorized
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if PreviewState.shouldSendPreviewHeader {
            request.setValue("1", forHTTPHeaderField: "X-Preview-As-User")
        }
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
            try applyAuthHeaders(to: &request)
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
            // Panne réseau : pour un GET on tente le dernier cache hors-ligne connu.
            if method == "GET", let cached = OfflineCache.shared.load(for: url.absoluteString) {
                do {
                    return try decoder.decode(T.self, from: cached)
                } catch {
                    throw NetworkError.requestFailed(error)
                }
            }
            throw NetworkError.requestFailed(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.requestFailed(NSError(domain: "InvalidResponse", code: -1))
        }

        switch httpResponse.statusCode {
        case 200...299:
            // Mémorise la dernière réponse GET pour la relire hors-ligne (lecture seule).
            if method == "GET" {
                OfflineCache.shared.store(data, for: url.absoluteString)
            }
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

    /// DELETE avec corps JSON (certains endpoints attendent un body, ex. suppression
    /// d'un billet d'étape identifié par son `url`/`path`/`index`).
    func delete<T: Decodable>(
        path: String,
        body: (any Encodable)?,
        requiresAuth: Bool = false
    ) async throws -> T {
        try await request(method: "DELETE", path: path, body: body, requiresAuth: requiresAuth)
    }

    // MARK: - Multipart upload

    /// Envoie un fichier en `multipart/form-data` sur `path` et décode la réponse.
    /// Réutilise l'auth Bearer et le décodeur de dates partagés. Utilisé pour
    /// l'upload de la couverture / des billets d'étape.
    /// - Parameters:
    ///   - fieldName: nom du champ de formulaire (ex. `cover`, `ticket`).
    ///   - fileData: contenu binaire du fichier.
    ///   - fileName: nom de fichier (avec extension correcte, ex. `billet.pdf`).
    ///   - mimeType: type MIME (ex. `application/pdf`, `image/jpeg`).
    func uploadMultipart<T: Decodable>(
        method: String = "POST",
        path: String,
        fieldName: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        requiresAuth: Bool = true
    ) async throws -> T {
        guard var components = URLComponents(url: APIConfig.baseURL, resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidURL
        }
        components.path += path
        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ios", forHTTPHeaderField: "X-Client-Platform")
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            request.setValue("ReveEtVoyage-iOS/\(appVersion)", forHTTPHeaderField: "User-Agent")
        }
        if requiresAuth {
            try applyAuthHeaders(to: &request)
        }

        var body = Data()
        let dd = "--\(boundary)\r\n"
        body.append(dd.data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

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

// MARK: - Offline cache (lecture seule)

/// Cache disque minimal des réponses GET pour le mode hors-ligne.
/// On mémorise le JSON brut de chaque GET réussi, indexé par l'URL complète
/// (chemin + query), et on le ressert quand le réseau est indisponible.
/// Lecture seule : aucune mutation n'est mise en file ici.
final class OfflineCache {
    static let shared = OfflineCache()

    private let dir: URL
    private let fm = FileManager.default

    private init() {
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        dir = base.appendingPathComponent("api-offline-cache", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private func fileURL(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return dir.appendingPathComponent(name)
    }

    func store(_ data: Data, for key: String) {
        try? data.write(to: fileURL(for: key), options: .atomic)
    }

    func load(for key: String) -> Data? {
        try? Data(contentsOf: fileURL(for: key))
    }

    /// Date de dernière mise à jour du cache pour cette clé
    /// (utile pour afficher « données du JJ/MM » en mode hors-ligne).
    func lastUpdated(for key: String) -> Date? {
        let path = fileURL(for: key).path
        return (try? fm.attributesOfItem(atPath: path))?[.modificationDate] as? Date
    }

    /// Purge totale du cache (à appeler à la déconnexion pour ne pas laisser
    /// les données d'un compte visibles à un autre).
    func clearAll() {
        try? fm.removeItem(at: dir)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }
}

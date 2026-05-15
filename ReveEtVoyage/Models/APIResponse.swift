import Foundation

// Generic wrapper for API responses that include metadata.
// `success` is optional because Laravel JsonResource collections only return {data, links, meta}.
struct APIResponse<T: Decodable>: Decodable {
    let success: Bool?
    let data: T?
    let message: String?
    let errors: [String: [String]]?
    let meta: PaginationMeta?

    enum CodingKeys: String, CodingKey {
        case success
        case data
        case message
        case errors
        case meta
    }
}

struct PaginationMeta: Decodable {
    let current_page: Int?
    let last_page: Int?
    let per_page: Int?
    let total: Int?
}

// Void response for endpoints that return no meaningful body (e.g. logout 204)
struct VoidResponse: Decodable {}

// Decodable error envelope returned by Laravel on 4xx/5xx
struct APIError: LocalizedError, Decodable {
    let success: Bool?
    let message: String?
    let errors: [String: [String]]?

    var errorDescription: String? {
        if let errors = errors, !errors.isEmpty {
            return errors.values.flatMap { $0 }.joined(separator: ", ")
        }
        return message ?? "Une erreur est survenue"
    }
}

// Surface-layer error type used throughout the app
enum NetworkError: LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case decodingFailed(Error)
    case serverError(statusCode: Int, message: String?)
    case unauthorized
    case validationError([String: [String]])
    case noInternetConnection

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL invalide"
        case .requestFailed(let error):
            return "Erreur réseau : \(error.localizedDescription)"
        case .decodingFailed:
            return "Erreur de décodage de la réponse"
        case .serverError(_, let message):
            return message ?? "Erreur serveur"
        case .unauthorized:
            return "Session expirée, veuillez vous reconnecter"
        case .validationError(let errors):
            let messages = errors.values.flatMap { $0 }.joined(separator: ", ")
            return "Erreur de validation : \(messages)"
        case .noInternetConnection:
            return "Pas de connexion Internet"
        }
    }
}

import Foundation

/// Admin-side full user record (mirror of GET /api/admin/users).
struct AdminUser: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let prenom: String?
    let email: String
    let phone: String?
    let role: String
    let adresse: String?
    let code_postal: String?
    let ville: String?
    let pays: String?
    let language: String?
    let last_login_at: String?
    let created_at: String?
    let voyages_count: Int?
    let passengers_count: Int?

    var fullName: String {
        let composed = "\(prenom ?? "") \(name)".trimmingCharacters(in: .whitespaces)
        return composed.isEmpty ? email : composed
    }
}

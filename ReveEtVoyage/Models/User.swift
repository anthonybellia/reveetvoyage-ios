import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let prenom: String
    let nom: String
    let email: String
    let phone: String?
    let avatar: String?
    let role: String
    let date_naissance: String?
    let nationalite: String?
    let adresse: String?
    let code_postal: String?
    let ville: String?
    let pays: String?
    let language: String?
    let notif_emails: Bool?
    let notif_promo: Bool?
    let notif_voyages: Bool?
    let last_login_at: String?
    let created_at: String

    var fullName: String {
        "\(prenom) \(nom)"
    }

    enum CodingKeys: String, CodingKey {
        case id, prenom, nom, email, phone, avatar, role
        case date_naissance, nationalite, adresse, code_postal, ville, pays
        case language, notif_emails, notif_promo, notif_voyages
        case last_login_at, created_at
    }
}

struct AuthResponse: Codable {
    let user: User
    let token: String
}

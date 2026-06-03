import Foundation

/// Résultat d'une recherche d'utilisateur par email exact.
/// Renvoyé par `GET /api/users/search?email=` dans `{ data: ... }`.
/// `data` vaut `null` si aucun compte ne correspond exactement.
struct UserSearchResult: Codable, Identifiable {
    let id: Int
    let prenom: String?
    let name: String?
    let email: String
    let avatar_url: String?

    /// Libellé d'affichage : privilégie le nom complet (`name`), retombe sur
    /// le prénom puis sur l'email.
    var displayName: String {
        if let n = name, !n.trimmingCharacters(in: .whitespaces).isEmpty { return n }
        if let p = prenom, !p.trimmingCharacters(in: .whitespaces).isEmpty { return p }
        return email
    }

    enum CodingKeys: String, CodingKey {
        case id, prenom, name, email, avatar_url
    }
}

/// Invitation reçue par l'utilisateur courant (en attente d'acceptation).
/// Renvoyée par `GET /api/invitations` dans le tableau `data`.
struct VoyageInvitation: Codable, Identifiable {
    let voyage: InvitedVoyage
    let role: String
    let inviter_name: String?
    let created_at: String?

    /// Identifiant stable pour les `ForEach` : l'id du voyage (une invitation
    /// par voyage et par utilisateur côté backend).
    var id: Int { voyage.id }

    /// Voyage référencé par l'invitation (sous-ensemble léger de `Voyage`).
    struct InvitedVoyage: Codable {
        let id: Int
        let titre: String?
        let destination: String?
        let date_depart: String?
        let date_retour: String?
        let image: String?

        enum CodingKeys: String, CodingKey {
            case id, titre, destination, date_depart, date_retour, image
        }
    }

    enum CodingKeys: String, CodingKey {
        case voyage, role, inviter_name, created_at
    }
}

/// Enveloppe brute de `GET /api/invitations` (`{ data: [...] }`).
struct InvitationsResponse: Decodable {
    let data: [VoyageInvitation]
}

/// Réponse brute des endpoints accept/decline (`{ ok, linked? }`).
struct InvitationActionResponse: Decodable {
    let ok: Bool?
    let linked: Bool?
}

/// Notification persistée côté serveur, listée par `GET /api/notifications`.
struct AppNotification: Codable, Identifiable {
    let id: Int
    let type: String?
    let titre: String?
    let message: String?
    let url: String?
    let lu: Bool
    let created_at: String?

    /// Vrai pour une invitation à un voyage : permet de router vers l'écran
    /// « Mes invitations » au tap.
    var isVoyageInvite: Bool { type == "voyage_invite" }

    enum CodingKeys: String, CodingKey {
        case id, type, titre, message, url, lu, created_at
    }
}

/// Enveloppe brute de `GET /api/notifications` (`{ data: [...], unread_count }`).
struct NotificationsResponse: Decodable {
    let data: [AppNotification]
    let unread_count: Int?
}

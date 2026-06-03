import Foundation

/// Note interne threadée attachée à un devis, réservée aux administrateurs.
///
/// À NE PAS confondre avec le champ unique `notes_admin` du devis (cf.
/// `DevisAdminPayload`/`DevisFormSheet`) : ici il s'agit d'une liste de notes
/// horodatées et signées par leur auteur, gérée via des endpoints dédiés.
struct DevisNote: Codable, Identifiable {
    let id: Int
    let contenu: String
    let author: String
    /// Date de création au format ISO 8601 renvoyée par l'API.
    let created_at: String

    enum CodingKeys: String, CodingKey {
        case id, contenu, author, created_at
    }
}

/// Corps de la requête de création d'une note interne.
struct DevisNoteCreateRequest: Encodable {
    let contenu: String
}

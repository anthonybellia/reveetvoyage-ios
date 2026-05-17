import Foundation

struct AdminDestination: Codable, Identifiable, Hashable {
    let id: Int
    let nom: String
    let slug: String?
    let continent: String
    let pays: String
    let description: String?
    let description_courte: String?
    let image_principale: String?
    let prix_depuis: Double?
    let duree_jours: Int?
    let featured: Bool
    let actif: Bool
    let meta_title: String?
    let meta_description: String?
}

struct AdminArticle: Codable, Identifiable, Hashable {
    let id: Int
    let titre: String
    let slug: String?
    let extrait: String?
    let contenu: String?
    let image: String?
    let meta_title: String?
    let meta_description: String?
    let publie: Bool
    let publie_le: String?
    let created_at: String?
    let updated_at: String?
}

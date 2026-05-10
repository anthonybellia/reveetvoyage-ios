import Foundation

struct Offre: Codable, Identifiable {
    let id: Int
    let nom: String
    let duree: String
    let prix: String
    let prix_suffixe: String
    let prix_label: String
    let description: String
    let features: [String]
    let populaire: Bool
    let couleur_fond: String
    let couleur_texte: String
    let badge_couleur: String
    let cta_texte: String
    let cta_lien: String
    let order: Int

    enum CodingKeys: String, CodingKey {
        case id, nom, duree, prix, description, features, populaire, order
        case prix_suffixe, prix_label, couleur_fond, couleur_texte, badge_couleur
        case cta_texte, cta_lien
    }
}

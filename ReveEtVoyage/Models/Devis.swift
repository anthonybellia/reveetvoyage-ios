import Foundation

struct Devis: Codable, Identifiable {
    let id: Int
    let token: String
    let nom: String
    let prenom: String
    let email: String
    let telephone: String?
    let nb_personnes: Int?
    let participants: String?
    let dates_souhaitees: String?
    let flexible_dates: String?
    let duree: String?
    let lieu_depart: String?
    let preferences_horaires: String?
    let destination: String?
    let destination_souhaitee: String?
    let ouvert_suggestions: String?
    let cadre: String?
    let hebergement: String?
    let besoins_specifiques: String?
    let activites: String?
    let activites_eviter: String?
    let imperatifs: String?
    let evenement: String?
    let budget: String?
    let type_voyage: String?
    let message: String?
    let statut: String
    let titre_voyage: String?
    let montant_estime: String?
    let date_depart_prevue: String?
    let date_retour_prevue: String?
    let voyage_id: Int?
    let created_at: String
    let updated_at: String

    enum CodingKeys: String, CodingKey {
        case id, token, nom, prenom, email, telephone, nb_personnes, participants
        case dates_souhaitees, flexible_dates, duree, lieu_depart, preferences_horaires
        case destination, destination_souhaitee, ouvert_suggestions, cadre, hebergement
        case besoins_specifiques, activites, activites_eviter, imperatifs, evenement
        case budget, type_voyage, message, statut, titre_voyage, montant_estime
        case date_depart_prevue, date_retour_prevue, voyage_id, created_at, updated_at
    }
}

enum DevisTypeVoyage: String, Codable, CaseIterable {
    case couple
    case famille
    case amis
    case solo
    case luneDeMiel = "lune_de_miel"

    var label: String {
        switch self {
        case .couple: return "Couple"
        case .famille: return "Famille"
        case .amis: return "Amis"
        case .solo: return "Solo"
        case .luneDeMiel: return "Lune de miel"
        }
    }
}

struct DevisCreateRequest: Encodable {
    let destination: String?
    let destination_souhaitee: String?
    let dates_souhaitees: String?
    let flexible_dates: String?
    let duree: String?
    let nb_personnes: Int?
    let participants: String?
    let lieu_depart: String?
    let preferences_horaires: String?
    let ouvert_suggestions: String?
    let cadre: String?
    let hebergement: String?
    let besoins_specifiques: String?
    let activites: String?
    let activites_eviter: String?
    let imperatifs: String?
    let evenement: String?
    let budget: String?
    let type_voyage: String
    let message: String?

    enum CodingKeys: String, CodingKey {
        case destination, destination_souhaitee, dates_souhaitees, flexible_dates
        case duree, nb_personnes, participants, lieu_depart, preferences_horaires
        case ouvert_suggestions, cadre, hebergement, besoins_specifiques
        case activites, activites_eviter, imperatifs, evenement, budget
        case type_voyage, message
    }
}

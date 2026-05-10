import Foundation

struct Voyage: Codable, Identifiable {
    let id: Int
    let reference: String
    let titre: String
    let destination: String
    let date_depart: String?
    let date_retour: String?
    let montant_total: Double
    let montant_acompte: Double
    let montant_paye: Double
    let acompte_type: String
    let acompte_valeur: Double
    let statut: String
    let statut_label: String
    let description: String?
    let participants: [String]?
    let token: String
    let etapes: [VoyageEtape]?
    let payments: [Payment]?
    let created_at: String
    let updated_at: String

    enum CodingKeys: String, CodingKey {
        case id, reference, titre, destination, statut, token, etapes, payments
        case date_depart, date_retour, montant_total, montant_acompte, montant_paye
        case acompte_type, acompte_valeur, statut_label, description, participants
        case created_at, updated_at
    }
}

struct VoyageEtape: Codable, Identifiable {
    let id: Int
    let ordre: Int
    let type: String
    let titre: String
    let description: String?
    let numero_ref: String?
    let compagnie: String?
    let date: String?
    let heure: String?
    let heure_retour: String?
    let lieu: String?
    let lieu_retour: String?
    let adresse: String?
    let cout: Double?
    let cout_note: String?
    let connector_mode: String?
    let connector_duration: String?
    let connector_distance: String?
    let details: String?
    let contenu_html: String?
    let image: String?
    let icon: String?
    let color: String?
    let is_completed: Bool
    let completed_at: String?

    enum CodingKeys: String, CodingKey {
        case id, ordre, type, titre, description, numero_ref, compagnie
        case date, heure, heure_retour, lieu, lieu_retour, adresse, cout, cout_note
        case connector_mode, connector_duration, connector_distance, details
        case contenu_html, image, icon, color, is_completed, completed_at
    }
}

struct Payment: Codable, Identifiable {
    let id: Int
    let montant: Double
    let statut: String
    let date_paiement: String?
    let methode: String?

    enum CodingKeys: String, CodingKey {
        case id, montant, statut, date_paiement, methode
    }
}

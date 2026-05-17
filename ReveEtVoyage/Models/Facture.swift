import Foundation

struct Facture: Codable, Identifiable, Hashable {
    let id: Int
    let numero: String
    let devis_id: Int?
    let voyage_id: Int?
    let user_id: Int?
    let communication: String?
    let client_nom: String
    let client_email: String?
    let client_adresse: String?
    let client_ville: String?
    let client_code_postal: String?
    let client_pays: String?
    let lignes: [FactureLigne]
    let sous_total: Double
    let tva_pct: Double
    let tva_montant: Double
    let total: Double
    let statut: String
    let notes: String?
    let date_emission: String?
    let date_echeance: String?
    let pdf_url: String
    let created_at: String?
    let updated_at: String?

    static func == (lhs: Facture, rhs: Facture) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct FactureLigne: Codable, Identifiable, Hashable {
    var id: String { description + reference }
    let description: String
    let reference: String
    let quantite: Double
    let prix_unitaire: Double
    let total: Double?

    enum CodingKeys: String, CodingKey {
        case description, reference, quantite, prix_unitaire, total
    }

    init(description: String, reference: String = "", quantite: Double, prix_unitaire: Double, total: Double? = nil) {
        self.description = description
        self.reference = reference
        self.quantite = quantite
        self.prix_unitaire = prix_unitaire
        self.total = total
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        reference = try c.decodeIfPresent(String.self, forKey: .reference) ?? ""
        quantite = (try? c.decode(Double.self, forKey: .quantite)) ?? Double((try? c.decode(String.self, forKey: .quantite)) ?? "0") ?? 0
        prix_unitaire = (try? c.decode(Double.self, forKey: .prix_unitaire)) ?? Double((try? c.decode(String.self, forKey: .prix_unitaire)) ?? "0") ?? 0
        total = try? c.decode(Double.self, forKey: .total)
    }
}

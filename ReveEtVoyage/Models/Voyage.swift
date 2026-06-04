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
    /// Présent uniquement quand le viewer est administrateur (cf. `ApiOwner`).
    let owner: ApiOwner?
    let created_at: String
    let updated_at: String

    enum CodingKeys: String, CodingKey {
        case id, reference, titre, destination, statut, token, etapes, payments
        case date_depart, date_retour, montant_total, montant_acompte, montant_paye
        case acompte_type, acompte_valeur, statut_label, description, participants
        case owner, created_at, updated_at
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
    let latitude: Double?
    let longitude: Double?
    let cout: Double?
    let cout_note: String?
    let connector_mode: String?
    let connector_duration: String?
    let connector_distance: String?
    let details: String?
    let contenu_html: String?
    let image: String?
    /// Image de couverture de l'étape (même URL que `image`, exposée par l'API).
    let cover: String?
    let fichier: String?
    let images: [String]?
    /// Billets / tickets attachés à l'étape (PDF, image…). Peut être vide.
    let tickets: [EtapeTicket]?
    let icon: String?
    let color: String?
    let is_completed: Bool
    let completed_at: String?

    var hasCoordinates: Bool { latitude != nil && longitude != nil }
    var hasAttachments: Bool {
        fichier != nil || image != nil || !(images ?? []).isEmpty || hasTickets
    }
    /// Vrai si l'étape comporte au moins un billet/ticket attaché.
    var hasTickets: Bool { !(tickets ?? []).isEmpty }

    /// URL de couverture de l'étape : privilégie `cover`, retombe sur `image`.
    var coverImage: String? {
        if let c = cover, !c.isEmpty { return c }
        if let i = image, !i.isEmpty { return i }
        return nil
    }

    var allImages: [String] {
        var result: [String] = []
        if let img = image, !img.isEmpty { result.append(img) }
        if let arr = images {
            for p in arr where !p.isEmpty && p != image {
                result.append(p)
            }
        }
        return result
    }

    /// Aperçu texte de la note pour la timeline : privilégie `description`,
    /// sinon retombe sur `contenu_html` débarrassé de ses balises HTML.
    /// Évite que les étapes dont le contenu n'existe que dans `contenu_html`
    /// (notes saisies via l'éditeur riche web) n'affichent rien dans la liste.
    var notePreview: String {
        if let d = description?.trimmingCharacters(in: .whitespacesAndNewlines), !d.isEmpty {
            return d
        }
        guard let html = contenu_html, !html.isEmpty else { return "" }
        var s = html
        // Balises de saut de ligne → espace, puis on retire toutes les balises.
        s = s.replacingOccurrences(of: "(?i)<br\\s*/?>|<hr[^>]*>|</p>|</div>|</li>",
                                   with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities = ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">",
                        "&#39;": "'", "&apos;": "'", "&quot;": "\""]
        for (k, v) in entities { s = s.replacingOccurrences(of: k, with: v) }
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum CodingKeys: String, CodingKey {
        case id, ordre, type, titre, description, numero_ref, compagnie
        case date, heure, heure_retour, lieu, lieu_retour, adresse
        case latitude, longitude, cout, cout_note
        case connector_mode, connector_duration, connector_distance, details
        case contenu_html, image, cover, fichier, images, tickets, icon, color, is_completed, completed_at
    }
}

/// Billet / ticket attaché à une étape (PDF, image…), exposé par l'API.
struct EtapeTicket: Codable, Identifiable {
    let url: String
    let name: String
    let ext: String
    let is_pdf: Bool
    let is_image: Bool
    /// Passager auquel le billet est attribué (VoyageParticipant), si défini.
    let participant_id: Int?
    let participant_name: String?

    /// Identifiant stable pour les `ForEach` (l'URL est unique par billet).
    var id: String { url }

    enum CodingKeys: String, CodingKey {
        case url, name, ext, is_pdf, is_image, participant_id, participant_name
    }
}

/// Description d'un type d'étape : SF Symbol + libellé français.
/// Source unique réutilisée par la timeline (`EtapeRow`) et le détail
/// (`EtapeDetailView`). Reflète l'ensemble des types gérés côté web.
struct EtapeTypeInfo {
    let icon: String
    let label: String

    /// Résout un type d'étape (clé API) vers son icône + libellé.
    /// Les types inconnus retombent sur une icône/libellé génériques.
    static func resolve(_ type: String) -> EtapeTypeInfo {
        switch type {
        case "vol_aller":   return EtapeTypeInfo(icon: "airplane.departure",      label: "Vol aller")
        case "vol_retour":  return EtapeTypeInfo(icon: "airplane.arrival",        label: "Vol retour")
        case "vol":         return EtapeTypeInfo(icon: "airplane",                label: "Vol")
        case "train":       return EtapeTypeInfo(icon: "tram.fill",               label: "Train")
        case "hotel":       return EtapeTypeInfo(icon: "bed.double.fill",         label: "Hôtel")
        case "activite":    return EtapeTypeInfo(icon: "figure.walk",             label: "Activité")
        case "restaurant":  return EtapeTypeInfo(icon: "fork.knife",              label: "Restaurant")
        case "brunch":      return EtapeTypeInfo(icon: "sun.max.fill",            label: "Brunch")
        case "petit_dej":   return EtapeTypeInfo(icon: "cup.and.saucer.fill",     label: "Petit-déjeuner")
        case "cafe":        return EtapeTypeInfo(icon: "cup.and.saucer.fill",     label: "Café")
        case "bar":         return EtapeTypeInfo(icon: "wineglass.fill",          label: "Bar")
        case "transfert":   return EtapeTypeInfo(icon: "car.fill",               label: "Transfert")
        case "visite":      return EtapeTypeInfo(icon: "building.columns.fill",   label: "Visite")
        case "monument":    return EtapeTypeInfo(icon: "building.columns.fill",   label: "Monument")
        case "croisiere":   return EtapeTypeInfo(icon: "ferry.fill",             label: "Croisière")
        case "note":        return EtapeTypeInfo(icon: "note.text",              label: "Note")
        case "spa":         return EtapeTypeInfo(icon: "sparkles",               label: "Spa")
        case "shopping":    return EtapeTypeInfo(icon: "bag.fill",               label: "Shopping")
        case "plage":       return EtapeTypeInfo(icon: "beach.umbrella.fill",     label: "Plage")
        case "sport":       return EtapeTypeInfo(icon: "figure.run",             label: "Sport")
        case "spectacle":   return EtapeTypeInfo(icon: "theatermasks.fill",       label: "Spectacle")
        case "document":    return EtapeTypeInfo(icon: "doc.fill",               label: "Document")
        default:            return EtapeTypeInfo(icon: "circle.fill",            label: type.capitalized)
        }
    }
}

/// Membre (collaborateur ou propriétaire) d'un voyage partagé.
/// Renvoyé par `GET /api/voyages/{id}/members` dans le tableau `members`.
struct VoyageMember: Codable, Identifiable {
    let id: Int
    let name: String
    let email: String
    let role: String
    let is_owner: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, email, role, is_owner
    }
}

/// Invitation en attente : l'email a été invité mais le compte n'est pas
/// encore lié au voyage (pas d'utilisateur correspondant pour l'instant).
/// Renvoyé dans le tableau `pending` de la même réponse.
struct PendingInvite: Codable {
    let email: String
    let role: String

    enum CodingKeys: String, CodingKey {
        case email, role
    }
}

/// Enveloppe brute de `GET /api/voyages/{id}/members`.
/// (La réponse n'est PAS encapsulée dans `{ data: ... }` comme les ressources
///  Laravel classiques, d'où un struct dédié plutôt que `APIResponse<T>`.)
struct VoyageMembersResponse: Decodable {
    let members: [VoyageMember]
    let pending: [PendingInvite]
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

import Foundation

/// Block "owner" injecté par le backend dans les ressources Devis/Voyage
/// uniquement quand le viewer est un administrateur (role == "admin").
///
/// Côté Laravel : `DevisResource` et `VoyageResource` exposent ce block
/// via `$this->when($request->user()?->role === 'admin', fn() => [...])`.
///
/// Quand `owner != nil`, on sait donc que le viewer regarde une ressource
/// qui ne lui appartient pas forcément → mode admin lecture seule.
struct ApiOwner: Codable, Hashable {
    let id: Int
    let prenom: String?
    let nom: String?
    let email: String?
    let phone: String?

    var fullName: String {
        let composed = "\(prenom ?? "") \(nom ?? "")"
            .trimmingCharacters(in: .whitespaces)
        return composed.isEmpty ? (email ?? "Utilisateur #\(id)") : composed
    }
}

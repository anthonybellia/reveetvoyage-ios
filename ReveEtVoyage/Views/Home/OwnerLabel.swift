import SwiftUI

/// Pavé "👤 Prénom Nom · email@x.com" affiché sous le titre d'une card
/// Devis ou Voyage **quand le viewer est admin** (i.e. `owner != nil` côté API).
///
/// Style : sous-texte secondaire, compact, garde la hiérarchie visuelle
/// de la card en place. Si l'owner n'a pas d'email, on n'affiche que le nom.
struct OwnerLabel: View {
    let owner: ApiOwner

    private var separator: String { owner.email != nil ? " · " : "" }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 11, weight: .medium))

            Text(owner.fullName)
                .font(.system(size: 12, weight: .semibold, design: .rounded))

            if let email = owner.email, !email.isEmpty {
                Text("·")
                    .font(.system(size: 12))
                    .opacity(0.5)
                Text(email)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .foregroundColor(.revTextSecondary)
        .padding(.top, 2)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 10) {
        OwnerLabel(owner: ApiOwner(
            id: 42, prenom: "Jean", nom: "Dupont",
            email: "jean.dupont@example.com", phone: "+32 470 11 22 33"
        ))
        OwnerLabel(owner: ApiOwner(
            id: 7, prenom: nil, nom: nil,
            email: "anon@example.com", phone: nil
        ))
        OwnerLabel(owner: ApiOwner(
            id: 8, prenom: "Marie", nom: "Curie",
            email: nil, phone: nil
        ))
    }
    .padding()
}

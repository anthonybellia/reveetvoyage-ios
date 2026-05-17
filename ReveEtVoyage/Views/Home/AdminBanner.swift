import SwiftUI

/// Banner discret affiché en haut des écrans quand l'utilisateur authentifié
/// est administrateur. Sert de rappel visuel que le viewer voit la donnée
/// de TOUS les users (Devis & Voyages bypass user filter côté backend).
///
/// Style : capsule horizontale jaune/doré semi-transparente, icône bouclier,
/// cohérent avec la palette `revYellow` / `revBrown`.
struct AdminBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.revBrown)

            Text("Mode admin · vue globale")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.revBrown)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.revYellow.opacity(0.25))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.revYellow.opacity(0.55), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mode administrateur activé, vous voyez la donnée de tous les utilisateurs")
    }
}

#Preview {
    VStack(spacing: 16) {
        AdminBanner()
    }
    .padding()
}

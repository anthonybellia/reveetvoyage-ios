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

/// Banner affiché quand un admin est en mode "aperçu client" : rappelle qu'il
/// voit l'app comme un voyageur, avec un bouton pour ressortir du mode aperçu.
struct PreviewModeBanner: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "eye")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.revBrown)

            Text("Aperçu client — tu vois ce que voit le voyageur")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.revBrown)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    authService.previewAsUser = false
                }
            } label: {
                Text("Quitter")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.revBrownDark))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.revOrange.opacity(0.15))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.revOrange.opacity(0.55), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mode aperçu client activé, touche Quitter pour revenir au mode admin")
    }
}

#Preview {
    VStack(spacing: 16) {
        AdminBanner()
        PreviewModeBanner()
            .environmentObject(AuthService.shared)
    }
    .padding()
}

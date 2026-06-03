import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showLogoutConfirm: Bool = false
    @State private var isLoggingOut: Bool = false
    @State private var showEditProfile: Bool = false
    @State private var showMessages: Bool = false
    @State private var showChangePassword: Bool = false
    @State private var showLanguage: Bool = false
    @State private var showNotificationsSettings: Bool = false

    struct PageDest: Hashable {
        let slug: String
        let title: String
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    profileHeader
                        .padding(.horizontal, 18)
                        .padding(.top, 8)

                    if authService.isRealAdmin {
                        adminPreviewToggle
                            .padding(.horizontal, 18)
                    }

                    accountSection
                        .padding(.horizontal, 18)

                    adminBoardSection
                        .padding(.horizontal, 18)

                    appSection
                        .padding(.horizontal, 18)

                    linksSection
                        .padding(.horizontal, 18)

                    legalSection
                        .padding(.horizontal, 18)

                    logoutButton
                        .padding(.horizontal, 18)
                        .padding(.top, 4)

                    versionFooter
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                }
            }
            .background(
                LinearGradient(colors: [Color.revYellow.opacity(0.10), Color.revBackground],
                               startPoint: .top, endPoint: .center)
                    .ignoresSafeArea()
            )
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog(
                "Se déconnecter ?",
                isPresented: $showLogoutConfirm,
                titleVisibility: .visible
            ) {
                Button("Se déconnecter", role: .destructive) {
                    Task {
                        isLoggingOut = true
                        await authService.logout()
                        isLoggingOut = false
                    }
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Tu devras te reconnecter pour accéder à ton compte.")
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView().environmentObject(authService)
            }
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordView().environmentObject(authService)
            }
            .sheet(isPresented: $showLanguage) {
                LanguageView().environmentObject(authService)
            }
            .sheet(isPresented: $showNotificationsSettings) {
                NotificationsSettingsView().environmentObject(authService)
            }
            .navigationDestination(isPresented: $showMessages) {
                MessagesView()
            }
            .navigationDestination(for: PageDest.self) { dest in
                PageView(slug: dest.slug, fallbackTitle: dest.title)
            }
        }
    }

    // MARK: - Profile

    private var profileHeader: some View {
        GlassCard(padding: 22) {
            VStack(spacing: 14) {
                if let user = authService.currentUser {
                    AvatarView(firstName: user.prenom, lastName: user.nom,
                               avatarPath: user.avatar, size: 80)

                    VStack(spacing: 3) {
                        Text(user.fullName)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.revText)
                        Text(user.email)
                            .font(.system(size: 13))
                            .foregroundColor(.revTextSecondary)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                        Text("Compte vérifié")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.revOrange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.revOrange.opacity(0.12)))
                } else {
                    ProgressView()
                        .tint(.revOrange)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Bascule admin / aperçu client

    /// Toggle réservé aux vrais admins : bascule entre le mode admin et le mode
    /// aperçu client (prévisualisation de l'expérience d'un voyageur normal).
    /// Visible en permanence pour pouvoir ressortir du mode aperçu.
    private var adminPreviewToggle: some View {
        let preview = authService.previewAsUser
        return GlassCard(padding: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    authService.previewAsUser.toggle()
                }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill((preview ? Color.revBrown : Color.revOrange).opacity(0.12))
                            .frame(width: 38, height: 38)
                        Image(systemName: preview ? "eye" : "person.crop.circle.badge.checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(preview ? .revBrown : .revOrange)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preview ? "Aperçu client" : "Mode admin")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.revText)
                        Text(preview
                             ? "Tu vois ce que voit le voyageur. Touche pour revenir."
                             : "Touche pour prévisualiser l'expérience client.")
                            .font(.system(size: 12))
                            .foregroundColor(.revTextSecondary)
                    }
                    Spacer()
                    Text(preview ? "Quitter" : "Aperçu")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(preview ? Color.revBrown : Color.revOrange))
                }
                .padding(14)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Sections

    private var accountSection: some View {
        GlassCard(padding: 0) {
            VStack(spacing: 0) {
                settingsRow(icon: "person.fill", title: "Informations personnelles",
                            subtitle: "Nom, email, téléphone", color: .revOrange) {
                    showEditProfile = true
                }
                Divider().padding(.leading, 60)
                settingsRow(icon: "lock.fill", title: "Mot de passe",
                            subtitle: "Modifier mon mot de passe", color: .revRed) {
                    showChangePassword = true
                }
                Divider().padding(.leading, 60)
                settingsRow(icon: "envelope.fill", title: "Mes messages",
                            subtitle: "Discussions avec l'équipe", color: .revYellow) {
                    showMessages = true
                }
                Divider().padding(.leading, 60)
                NavigationLink(destination: InvitationsView()) {
                    settingsRowLabel(
                        icon: "envelope.open.fill",
                        title: "Mes invitations",
                        subtitle: "Voyages partagés en attente",
                        color: .revRed
                    )
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 60)
                NavigationLink(destination: PackingTemplateView()) {
                    settingsRowLabel(
                        icon: "suitcase.fill",
                        title: "Ma liste de bagage",
                        subtitle: "Ta liste type réutilisable",
                        color: .revOrange
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var adminBoardSection: some View {
        let isAdmin = authService.isAdmin
        return VStack(alignment: .leading, spacing: 8) {
            Text(isAdmin ? "ADMINISTRATION" : "DOCUMENTS")
                .font(.caption.weight(.semibold))
                .foregroundColor(.revTextSecondary)
                .padding(.leading, 8)
            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    NavigationLink {
                        FactureListView()
                    } label: {
                        settingsRowLabel(
                            icon: "doc.text.fill",
                            title: isAdmin ? "Factures" : "Mes factures",
                            subtitle: isAdmin ? "Gérer toutes les factures" : "Historique de mes factures",
                            color: .revOrange
                        )
                    }
                    .buttonStyle(.plain)

                    if isAdmin {
                        Divider().padding(.leading, 60)
                        NavigationLink {
                            AdminUserListView()
                        } label: {
                            settingsRowLabel(
                                icon: "person.2.fill",
                                title: "Utilisateurs",
                                subtitle: "Clients, admins, modérateurs",
                                color: .revRed
                            )
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 60)
                        NavigationLink {
                            AdminDestinationsView()
                        } label: {
                            settingsRowLabel(
                                icon: "map.fill",
                                title: "Destinations",
                                subtitle: "Catalogue du site",
                                color: .revYellow
                            )
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 60)
                        NavigationLink {
                            AdminArticlesView()
                        } label: {
                            settingsRowLabel(
                                icon: "doc.richtext.fill",
                                title: "Articles",
                                subtitle: "Blog & contenu éditorial",
                                color: .revBrown
                            )
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 60)
                        NavigationLink {
                            AdminSettingsView()
                        } label: {
                            settingsRowLabel(
                                icon: "slider.horizontal.3",
                                title: "Paramètres site",
                                subtitle: "Marque, paiements, SEO, socials",
                                color: .revOrange
                            )
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 60)
                        NavigationLink {
                            AdminEmailTemplatesView()
                        } label: {
                            settingsRowLabel(
                                icon: "envelope.fill",
                                title: "Templates emails",
                                subtitle: "Sujets, contenus, test d'envoi",
                                color: .revRed
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// Reusable row label (used inside NavigationLink containers).
    private func settingsRowLabel(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.revText)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.revTextSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.revTextSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var appSection: some View {
        GlassCard(padding: 0) {
            VStack(spacing: 0) {
                settingsRow(icon: "bell.fill", title: "Notifications",
                            subtitle: "Email + rappels voyage", color: .revOrange) {
                    showNotificationsSettings = true
                }
                Divider().padding(.leading, 60)
                settingsRow(icon: "globe", title: "Langue",
                            subtitle: currentLanguageLabel, color: .revOrange) {
                    showLanguage = true
                }
            }
        }
    }

    private var currentLanguageLabel: String {
        switch authService.currentUser?.language {
        case "en": return "English"
        case "nl": return "Nederlands"
        default:   return "Français"
        }
    }

    @Environment(\.openURL) private var openURL

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LIENS UTILES")
                .font(.caption.weight(.semibold))
                .foregroundColor(.revTextSecondary)
                .padding(.leading, 8)

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    settingsRow(icon: "globe", title: "Site web",
                                subtitle: "reveetvoyage.be", color: .blue) {
                        openLink("https://www.reveetvoyage.be")
                    }
                    Divider().padding(.leading, 60)
                    settingsRow(icon: "phone.fill", title: "Téléphone",
                                subtitle: "+32 497 02 85 20", color: .green) {
                        openLink("tel:+32497028520")
                    }
                    Divider().padding(.leading, 60)
                    settingsRow(icon: "envelope.fill", title: "Email",
                                subtitle: "contact@reveetvoyage.be", color: .revOrange) {
                        openLink("mailto:contact@reveetvoyage.be")
                    }
                    Divider().padding(.leading, 60)
                    settingsRow(icon: "camera.fill", title: "Instagram",
                                subtitle: "@matilda_travelplanner", color: .pink) {
                        openLink("https://www.instagram.com/matilda_travelplanner")
                    }
                    Divider().padding(.leading, 60)
                    settingsRow(icon: "creditcard.fill", title: "Revolut",
                                subtitle: "Carte voyage sans frais", color: .purple) {
                        openLink("https://revolut.com/referral/?referral-code=mlarosa97!MAY2-26-AR-H1&geo-redirect")
                    }
                    Divider().padding(.leading, 60)
                    settingsRow(icon: "wifi", title: "Holafly",
                                subtitle: "eSIM data internationale", color: .cyan) {
                        openLink("https://www.holafly.com/?ref=reveetvoyage")
                    }
                    Divider().padding(.leading, 60)
                    settingsRow(icon: "star.bubble.fill", title: "Avis Google",
                                subtitle: "Laisse-nous un avis", color: .red) {
                        openLink("https://share.google/FYbXWUrKluGlWeJ9N")
                    }
                    Divider().padding(.leading, 60)
                    settingsRow(icon: "star.fill", title: "Noter l'app",
                                subtitle: "Sur l'App Store", color: .yellow) {
                        openLink("https://apps.apple.com/app/id0?action=write-review")
                    }
                    Divider().padding(.leading, 60)
                    settingsRow(icon: "square.and.arrow.up.fill", title: "Partager Rêve et Voyage",
                                subtitle: "Envoie l'app à un ami", color: .revRed) {
                        shareApp()
                    }
                }
            }
        }
    }

    private func openLink(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        openURL(url)
    }

    private func shareApp() {
        let text = "Découvre Rêve et Voyage — l'app pour organiser tes voyages 🌴 https://www.reveetvoyage.be"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController { topVC = presented }
            topVC.present(activityVC, animated: true)
        }
    }

    private var legalSection: some View {
        GlassCard(padding: 0) {
            VStack(spacing: 0) {
                NavigationLink(value: PageDest(slug: "conditions-generales", title: "Conditions générales")) {
                    settingsRowContent(icon: "doc.text.fill", title: "Conditions générales",
                                       subtitle: "Lire les CGU", color: .revTextSecondary)
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 60)
                NavigationLink(value: PageDest(slug: "politique-de-confidentialite", title: "Confidentialité")) {
                    settingsRowContent(icon: "hand.raised.fill", title: "Confidentialité",
                                       subtitle: "Protection des données", color: .revTextSecondary)
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 60)
                NavigationLink(value: PageDest(slug: "conditions-de-vente", title: "Conditions de vente")) {
                    settingsRowContent(icon: "scroll.fill", title: "Conditions de vente",
                                       subtitle: "CGV applicables", color: .revTextSecondary)
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 60)
                settingsRow(icon: "questionmark.circle.fill", title: "Aide",
                            subtitle: "Contacte l'équipe Rêve et Voyage", color: .revTextSecondary) {
                    showMessages = true
                }
            }
        }
    }

    private func settingsRow(icon: String, title: String, subtitle: String?, color: Color,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            settingsRowContent(icon: icon, title: title, subtitle: subtitle, color: color)
        }
        .buttonStyle(.plain)
    }

    private func settingsRowContent(icon: String, title: String, subtitle: String?, color: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(
                    LinearGradient(colors: [color.opacity(0.85), color],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.revText)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.revTextSecondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.revTextSecondary.opacity(0.5))
        }
        .padding(14)
    }

    // MARK: - Logout

    private var logoutButton: some View {
        BrandButton(
            title: "Se déconnecter",
            systemImage: "rectangle.portrait.and.arrow.right",
            isLoading: isLoggingOut,
            style: .destructive
        ) {
            showLogoutConfirm = true
        }
    }

    private var versionFooter: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image("Icon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                Text("Rêve et Voyage")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.revBrown)
            }
            Text("Version 1.0 · Build Phase 4")
                .font(.system(size: 10))
                .foregroundColor(.revTextSecondary)
        }
    }
}

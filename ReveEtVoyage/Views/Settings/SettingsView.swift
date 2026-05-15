import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showLogoutConfirm: Bool = false
    @State private var isLoggingOut: Bool = false
    @State private var showEditProfile: Bool = false
    @State private var showMessages: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    profileHeader
                        .padding(.horizontal, 18)
                        .padding(.top, 8)

                    accountSection
                        .padding(.horizontal, 18)

                    appSection
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
                EditProfileView()
                    .environmentObject(authService)
            }
            .navigationDestination(isPresented: $showMessages) {
                MessagesView()
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
                    // TODO: future
                }
                Divider().padding(.leading, 60)
                settingsRow(icon: "envelope.fill", title: "Mes messages",
                            subtitle: "Discussions avec l'équipe", color: .revYellow) {
                    showMessages = true
                }
            }
        }
    }

    private var appSection: some View {
        GlassCard(padding: 0) {
            VStack(spacing: 0) {
                settingsRow(icon: "bell.fill", title: "Notifications",
                            subtitle: "Gérer mes alertes", color: .revOrange) {}
                Divider().padding(.leading, 60)
                settingsRow(icon: "globe", title: "Langue",
                            subtitle: "Français", color: .revOrange) {}
            }
        }
    }

    private var legalSection: some View {
        GlassCard(padding: 0) {
            VStack(spacing: 0) {
                settingsRow(icon: "doc.text.fill", title: "Conditions générales",
                            subtitle: nil, color: .revTextSecondary) {}
                Divider().padding(.leading, 60)
                settingsRow(icon: "hand.raised.fill", title: "Confidentialité",
                            subtitle: nil, color: .revTextSecondary) {}
                Divider().padding(.leading, 60)
                settingsRow(icon: "questionmark.circle.fill", title: "Aide",
                            subtitle: nil, color: .revTextSecondary) {}
            }
        }
    }

    private func settingsRow(icon: String, title: String, subtitle: String?, color: Color,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
        .buttonStyle(.plain)
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

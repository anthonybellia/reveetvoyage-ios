import SwiftUI

struct DevisDetailView: View {
    let devis: Devis
    @State private var appear: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroCard
                    .padding(.horizontal, 18)
                    .padding(.top, 8)

                detailsCard
                    .padding(.horizontal, 18)

                if !preferencesItems.isEmpty {
                    preferencesCard
                        .padding(.horizontal, 18)
                }

                if let message = devis.message, !message.isEmpty {
                    messageCard(message)
                        .padding(.horizontal, 18)
                }
            }
            .padding(.bottom, 30)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 16)
        }
        .background(
            LinearGradient(colors: [Color.revYellow.opacity(0.08), Color.revBackground],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        )
        .navigationTitle("Demande #\(devis.id)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { appear = true }
        }
    }

    private var heroCard: some View {
        GlassCard(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        StatusBadge.devisStatut(devis.statut)
                        Text(devis.titre_voyage ?? devis.destination_souhaitee ?? "Demande de voyage")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.revText)
                    }
                    Spacer()
                    Image(systemName: heroIcon)
                        .font(.system(size: 38))
                        .foregroundStyle(LinearGradient(colors: [.revOrange, .revRed],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing))
                }

                if let dest = devis.destination ?? devis.destination_souhaitee {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 13))
                        Text(dest)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.revTextSecondary)
                }

                if let owner = devis.owner {
                    OwnerLabel(owner: owner)
                }
            }
        }
    }

    private var heroIcon: String {
        switch devis.type_voyage {
        case "couple": return "heart.circle.fill"
        case "famille": return "figure.2.and.child.holdinghands"
        case "amis": return "person.3.fill"
        case "solo": return "figure.wave"
        case "lune_de_miel": return "sparkles"
        default: return "airplane.circle.fill"
        }
    }

    private var detailsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "Détails", systemImage: "info.circle.fill")

                detailRow(icon: "person.2.fill", label: "Voyageurs",
                          value: devis.nb_personnes.map { "\($0) personne(s)" } ?? "—")
                detailRow(icon: "calendar", label: "Dates",
                          value: devis.dates_souhaitees ?? devis.flexible_dates ?? "—")
                detailRow(icon: "clock", label: "Durée", value: devis.duree ?? "—")
                detailRow(icon: "airplane.departure", label: "Départ depuis",
                          value: devis.lieu_depart ?? "—")
                detailRow(icon: "eurosign.circle", label: "Budget",
                          value: devis.budget ?? "—")
                detailRow(icon: "heart.fill", label: "Type de voyage",
                          value: devis.type_voyage?.replacingOccurrences(of: "_", with: " ").capitalized ?? "—")
            }
        }
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.revOrange)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.revTextSecondary)
                Text(value)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.revText)
            }
            Spacer()
        }
    }

    private var preferencesItems: [(String, String)] {
        var items: [(String, String)] = []
        if let v = devis.cadre, !v.isEmpty { items.append(("Cadre", v)) }
        if let v = devis.hebergement, !v.isEmpty { items.append(("Hébergement", v)) }
        if let v = devis.activites, !v.isEmpty { items.append(("Activités", v)) }
        if let v = devis.activites_eviter, !v.isEmpty { items.append(("À éviter", v)) }
        if let v = devis.imperatifs, !v.isEmpty { items.append(("Impératifs", v)) }
        if let v = devis.evenement, !v.isEmpty { items.append(("Événement", v)) }
        if let v = devis.besoins_specifiques, !v.isEmpty { items.append(("Besoins spécifiques", v)) }
        return items
    }

    private var preferencesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: "Préférences", systemImage: "slider.horizontal.3")
                ForEach(preferencesItems, id: \.0) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.0)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.revTextSecondary)
                        Text(item.1)
                            .font(.system(size: 13))
                            .foregroundColor(.revText)
                    }
                }
            }
        }
    }

    private func messageCard(_ message: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "Ton message", systemImage: "text.quote")
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.revText)
            }
        }
    }
}

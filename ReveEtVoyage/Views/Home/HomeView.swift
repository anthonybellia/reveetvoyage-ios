import CoreLocation
import SwiftUI

struct HomeView: View {
    let onSwitchTab: (MainTabView.Tab) -> Void

    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var locationService = LocationService.shared
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var deepLink: DeepLinkRouter
    @State private var heroAppear: Bool = false
    @State private var unreadCount: Int = 0
    @State private var navPath = NavigationPath()
    @State private var openMessagesWithDraft: String? = nil
    @State private var weather: WeatherResponse? = nil
    @State private var weatherLoading: Bool = false
    @State private var weatherLocationLabel: String? = nil

    var body: some View {
        NavigationStack(path: $navPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    if authService.currentUser?.role == "admin" {
                        AdminBanner()
                            .padding(.horizontal, 20)
                    }

                    quickActions
                        .padding(.horizontal, 20)

                    WeatherCard(
                        weather: weather,
                        locationLabel: weatherLocationLabel,
                        isLoading: weatherLoading,
                    )
                    .padding(.horizontal, 20)

                    if viewModel.isLoading && viewModel.voyages.isEmpty && viewModel.recentDevis.isEmpty {
                        ProgressView()
                            .tint(.revOrange)
                            .padding(.top, 60)
                            .frame(maxWidth: .infinity)
                    } else {
                        upcomingVoyagesSection
                            .padding(.horizontal, 20)

                        pendingDevisSection
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 40)
            }
            .background(backgroundGradient.ignoresSafeArea())
            .navigationBarHidden(true)
            .refreshable { await viewModel.loadData() }
            .task {
                await viewModel.loadData()
                await loadUnreadCount()
                await loadWeather()
                withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
                    heroAppear = true
                }
            }
            .onChange(of: locationService.lastKnownLocation) { _ in
                Task { await loadWeather() }
            }
            .navigationDestination(for: Int.self) { id in
                VoyageDetailView(voyageId: id)
            }
            .navigationDestination(isPresented: Binding(
                get: { openMessagesWithDraft != nil },
                set: { if !$0 { openMessagesWithDraft = nil } }
            )) {
                MessagesView(initialDraft: openMessagesWithDraft)
            }
            .onChange(of: deepLink.pendingVoyageId) { newId in
                if let newId {
                    navPath.append(newId)
                    deepLink.pendingVoyageId = nil
                }
            }
        }
    }

    private func loadUnreadCount() async {
        do {
            unreadCount = try await MessageService.shared.unreadCount()
        } catch {
            unreadCount = 0
        }
    }

    private func loadWeather() async {
        let coord = locationService.lastKnownLocation?.coordinate
            ?? CLLocationCoordinate2D(latitude: 50.8503, longitude: 4.3517) // fallback Brussels

        let label: String? = await reverseGeocode(coord) ?? "Belgique"
        weatherLocationLabel = label

        weatherLoading = (weather == nil)
        do {
            weather = try await WeatherService.shared.fetch(latitude: coord.latitude, longitude: coord.longitude)
        } catch {
            #if DEBUG
            print("[HomeView] weather fetch failed: \(error)")
            #endif
        }
        weatherLoading = false
    }

    private func reverseGeocode(_ coord: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        return await withCheckedContinuation { cont in
            CLGeocoder().reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "fr_FR")) { placemarks, _ in
                let pm = placemarks?.first
                let city = pm?.locality ?? pm?.subAdministrativeArea ?? pm?.administrativeArea
                cont.resume(returning: city)
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.revYellow.opacity(0.15),
                Color.revBackground
            ],
            startPoint: .top,
            endPoint: .center
        )
    }

    // MARK: - Hero

    private var heroHeader: some View {
        HStack(spacing: 14) {
            if let user = authService.currentUser {
                AvatarView(firstName: user.prenom, lastName: user.nom,
                           avatarPath: user.avatar, size: 52)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Bonjour,")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.revTextSecondary)
                    Text(user.prenom)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.revText)
                }
            }
            Spacer()

            NavigationLink {
                NotificationsView()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.revBrown)
                        .frame(width: 44, height: 44)
                        .background(Color.revCardBackground)
                        .clipShape(Circle())

                    if unreadCount > 0 {
                        Text("\(unreadCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(Color.revRed)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.revBackground, lineWidth: 2))
                            .offset(x: 4, y: -4)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .opacity(heroAppear ? 1 : 0)
        .offset(y: heroAppear ? 0 : -10)
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        HStack(spacing: 12) {
            QuickActionCard(
                title: "Nouveau voyage",
                subtitle: "Demande un devis",
                systemImage: "airplane.departure",
                gradient: [.revYellow, .revOrange],
                action: {
                    openMessagesWithDraft = "Bonjour ! J'aimerais faire une demande de voyage. Voici mes critères :\n\n• Destination : \n• Dates souhaitées : \n• Nombre de personnes : \n• Type (couple/famille/amis/solo/lune de miel) : \n• Budget approximatif : \n\nMerci !"
                }
            )
            QuickActionCard(
                title: "Mes passagers",
                subtitle: "Gérer la liste",
                systemImage: "person.2.fill",
                gradient: [.revOrange, .revRed],
                action: { onSwitchTab(.passengers) }
            )
        }
    }

    // MARK: - Upcoming voyages

    private var upcomingVoyagesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "Mes voyages", systemImage: "airplane",
                         trailing: viewModel.voyages.isEmpty ? nil : "\(viewModel.voyages.count)")

            if viewModel.voyages.isEmpty {
                GlassCard {
                    VStack(spacing: 8) {
                        Image(systemName: "suitcase.rolling")
                            .font(.system(size: 32))
                            .foregroundColor(.revOrange.opacity(0.6))
                        Text("Aucun voyage programmé")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.revTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.voyages.prefix(3)) { voyage in
                        NavigationLink(value: voyage.id) {
                            VoyageCard(voyage: voyage)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Pending devis

    private var pendingDevisSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "En attente de validation", systemImage: "clock.fill",
                         trailing: viewModel.recentDevis.isEmpty ? nil : "\(viewModel.recentDevis.count)")

            if viewModel.recentDevis.isEmpty {
                GlassCard {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 32))
                            .foregroundColor(.revOrange.opacity(0.6))
                        Text("Aucune demande en cours")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.revTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.recentDevis.prefix(3)) { devis in
                        DevisRow(devis: devis)
                    }
                }
            }
        }
    }
}

// MARK: - Quick action card

private struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let gradient: [Color]
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.18))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: gradient.last!.opacity(0.3), radius: 10, x: 0, y: 6)
        .scaleEffect(hover ? 0.97 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hover)
        .onTapGesture {
            withAnimation { hover = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation { hover = false }
                action()
            }
        }
    }
}

// MARK: - Voyage card

struct VoyageCard: View {
    let voyage: Voyage

    private var dateRange: String? {
        guard let depart = voyage.date_depart?.toDate() else { return nil }
        let retour = voyage.date_retour?.toDate()
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_BE")
        f.dateFormat = "d MMM"
        let start = f.string(from: depart)
        if let retour {
            return "\(start) → \(f.string(from: retour))"
        }
        return start
    }

    var body: some View {
        GlassCard(padding: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.revYellow.opacity(0.6), .revOrange.opacity(0.6)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 50, height: 50)
                    Image(systemName: "airplane")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(-30))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(voyage.titre)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.revText)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11))
                        Text(voyage.destination)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.revTextSecondary)

                    if let dateRange {
                        Text(dateRange)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.revOrange)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    StatusBadge.voyageStatut(voyage.statut, label: voyage.statut_label)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.revTextSecondary)
                }
            }
        }
    }
}

// MARK: - Devis row

struct DevisRow: View {
    let devis: Devis

    var body: some View {
        GlassCard(padding: 14) {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.revOrange)
                    .frame(width: 36, height: 36)
                    .background(Color.revOrange.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(devis.titre_voyage ?? devis.destination ?? devis.destination_souhaitee ?? "Demande de voyage")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.revText)
                        .lineLimit(1)

                    if let typ = devis.type_voyage {
                        Text(typ.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.system(size: 11))
                            .foregroundColor(.revTextSecondary)
                    }
                }

                Spacer()

                StatusBadge.devisStatut(devis.statut)
            }
        }
    }
}

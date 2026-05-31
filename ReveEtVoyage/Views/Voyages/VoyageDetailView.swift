import SwiftUI
import MapKit

struct EtapeNavValue: Hashable {
    let etape: VoyageEtape
    func hash(into hasher: inout Hasher) { hasher.combine(etape.id) }
    static func == (lhs: EtapeNavValue, rhs: EtapeNavValue) -> Bool { lhs.etape.id == rhs.etape.id }
}

struct ExpensesNavValue: Hashable {
    let voyageId: Int
}

struct PackingNavValue: Hashable {
    let voyageId: Int
}

struct VoyageDetailView: View {
    @StateObject private var viewModel: VoyageDetailViewModel
    @State private var celebrate: Bool = false
    @State private var confettiBurst: Int = 0
    @State private var showToggleConfirm: Bool = false
    @State private var pendingToggleEtape: VoyageEtape? = nil

    @State private var adminSheet: AdminSheetItem? = nil
    @State private var pendingDeleteEtape: VoyageEtape? = nil
    @State private var showDeleteConfirm: Bool = false

    @State private var showTripCompletedOverlay: Bool = false
    @State private var openNewTripMessage: Bool = false
    @State private var showEditVoyageSheet: Bool = false
    @State private var showDeleteVoyageConfirm: Bool = false
    @Environment(\.dismiss) private var dismissVoyageDetail
    private let newTripDraft = "Bonjour ! Je viens de rentrer et j'aimerais préparer mon prochain voyage. Voici mes premières idées :\n\n• Destination envisagée : \n• Dates souhaitées : \n• Type de séjour : \n• Budget approximatif : \n\nMerci !"

    private struct AdminSheetItem: Identifiable {
        let id: String
        let mode: EtapeFormSheet.Mode
    }

    private var isAdmin: Bool {
        AuthService.shared.currentUser?.role == "admin"
    }

    init(voyageId: Int) {
        _viewModel = StateObject(wrappedValue: VoyageDetailViewModel(voyageId: voyageId))
    }

    var body: some View {
        ZStack {
            backgroundLayer

            if viewModel.isLoading && viewModel.voyage == nil {
                LoadingView()
            } else if let error = viewModel.errorMessage, viewModel.voyage == nil {
                ErrorView(message: error) { Task { await viewModel.load() } }
            } else if let voyage = viewModel.voyage {
                ScrollView {
                    VStack(spacing: 16) {
                        if let heroEtape = firstGeoEtape() {
                            VoyageHero(etape: heroEtape)
                        }
                        VStack(spacing: 20) {
                            headerCard(voyage: voyage)
                            progressCard(voyage: voyage)
                            expensesEntryButton(voyageId: voyage.id)
                            packingEntryButton(voyageId: voyage.id)
                            timelineSection
                        }
                        .padding(.horizontal, 18)
                    }
                    .padding(.bottom, 16)
                }
                .refreshable { await viewModel.load() }
            }

            if celebrate {
                CelebrationOverlay(burst: confettiBurst)
                    .allowsHitTesting(false)
            }

            if showTripCompletedOverlay, let voyage = viewModel.voyage {
                TripCompletedOverlay(
                    voyage: voyage,
                    onClose: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showTripCompletedOverlay = false
                        }
                    },
                    onNewTrip: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showTripCompletedOverlay = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            openNewTripMessage = true
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let voyage = viewModel.voyage {
                    Text(voyage.reference)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.revBrown)
                }
            }
        }
        .navigationDestination(for: EtapeNavValue.self) { value in
            if let voyage = viewModel.voyage {
                EtapeDetailView(voyage: voyage, etape: currentEtape(value.etape), viewModel: viewModel)
            }
        }
        .navigationDestination(for: ExpensesNavValue.self) { value in
            ExpensesView(voyageId: value.voyageId)
        }
        .navigationDestination(for: PackingNavValue.self) { value in
            PackingView(voyageId: value.voyageId)
        }
        .confirmationDialog(
            (pendingToggleEtape?.is_completed == true)
                ? "Marquer comme non effectuée ?"
                : "As-tu bien réalisé cette étape ?",
            isPresented: $showToggleConfirm,
            titleVisibility: .visible
        ) {
            if let etape = pendingToggleEtape {
                Button(etape.is_completed ? "Marquer non effectuée" : "Oui, c'est fait ✅",
                       role: etape.is_completed ? .destructive : nil) {
                    handleToggle(etape)
                    pendingToggleEtape = nil
                }
                Button("Annuler", role: .cancel) { pendingToggleEtape = nil }
            }
        } message: {
            if pendingToggleEtape?.is_completed == false {
                Text("Tu peux passer à l'étape suivante. On te rappellera les prochaines.")
            }
        }
        .toolbar {
            if isAdmin, let voyage = viewModel.voyage {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            adminSheet = AdminSheetItem(
                                id: "create-\(voyage.id)-\(UUID())",
                                mode: .create(voyageId: voyage.id)
                            )
                        } label: {
                            Label("Ajouter une étape", systemImage: "plus.circle")
                        }
                        Button {
                            showEditVoyageSheet = true
                        } label: {
                            Label("Modifier le voyage", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showDeleteVoyageConfirm = true
                        } label: {
                            Label("Supprimer le voyage", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundColor(.revOrange)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditVoyageSheet) {
            if let voyage = viewModel.voyage {
                VoyageFormSheet(mode: .edit(voyage)) { updated in
                    viewModel.voyage = updated
                }
            }
        }
        .confirmationDialog(
            "Supprimer ce voyage ?",
            isPresented: $showDeleteVoyageConfirm,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                Task {
                    if let voyage = viewModel.voyage {
                        try? await VoyageService.shared.deleteVoyage(id: voyage.id)
                        dismissVoyageDetail()
                    }
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            if let voyage = viewModel.voyage {
                Text("\(voyage.titre) et toutes ses étapes seront supprimés définitivement.")
            }
        }
        .sheet(item: $adminSheet) { item in
            EtapeFormSheet(mode: item.mode) { saved in
                viewModel.upsertEtape(saved)
            }
        }
        .sheet(isPresented: $openNewTripMessage) {
            NavigationView {
                MessagesView(initialDraft: newTripDraft)
            }
        }
        .onChange(of: viewModel.completedCount) { _ in
            maybeShowTripCompletedOverlay()
        }
        .onChange(of: viewModel.totalCount) { _ in
            maybeShowTripCompletedOverlay()
        }
        .confirmationDialog(
            "Supprimer cette étape ?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            if let etape = pendingDeleteEtape {
                Button("Supprimer", role: .destructive) {
                    Task { await viewModel.deleteEtape(etape) }
                    pendingDeleteEtape = nil
                }
                Button("Annuler", role: .cancel) { pendingDeleteEtape = nil }
            }
        } message: {
            if let etape = pendingDeleteEtape {
                Text("\(etape.titre) sera supprimée définitivement.")
            }
        }
        .task { await viewModel.load() }
    }

    /// Use the live version from viewModel (in case it was just toggled)
    private func currentEtape(_ original: VoyageEtape) -> VoyageEtape {
        viewModel.etapes.first(where: { $0.id == original.id }) ?? original
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [Color.revYellow.opacity(0.10), Color.revBackground],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Header

    private func headerCard(voyage: Voyage) -> some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(voyage.titre)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.revText)
                        HStack(spacing: 5) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 13))
                            Text(voyage.destination)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.revTextSecondary)
                    }
                    Spacer()
                    StatusBadge.voyageStatut(voyage.statut, label: voyage.statut_label)
                }

                if let owner = voyage.owner {
                    OwnerLabel(owner: owner)
                }

                if voyage.date_depart != nil || voyage.date_retour != nil {
                    HStack(spacing: 18) {
                        dateChip(label: "Départ", iso: voyage.date_depart, icon: "airplane.departure")
                        dateChip(label: "Retour", iso: voyage.date_retour, icon: "airplane.arrival")
                    }
                }

                if let participants = voyage.participants, !participants.isEmpty {
                    participantsRow(participants)
                }

                if voyage.montant_total > 0 {
                    HStack(spacing: 10) {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.revOrange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formatPrice(voyage.montant_paye) + " / " + formatPrice(voyage.montant_total))
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(.revText)
                            Text("Acompte : \(formatPrice(voyage.montant_acompte))")
                                .font(.system(size: 11))
                                .foregroundColor(.revTextSecondary)
                        }
                    }
                }
            }
        }
    }

    private func participantsRow(_ participants: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 11))
                Text("VOYAGEURS (\(participants.count))")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.revOrange)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(participants, id: \.self) { name in
                        HStack(spacing: 4) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 12))
                            Text(name)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.revBrown)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.revYellow.opacity(0.25)))
                    }
                }
            }
        }
    }

    private func dateChip(label: String, iso: String?, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.revOrange)

            Text(iso?.toDate()?.formatted(style: .medium) ?? "—")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.revText)
        }
    }

    private func formatPrice(_ amount: Double) -> String {
        String(format: "€%.0f", amount)
    }

    // MARK: - Progress

    private func progressCard(voyage: Voyage) -> some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Progression du planning")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.revText)
                    Spacer()
                    Text("\(viewModel.completedCount) / \(viewModel.totalCount)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.revOrange)
                }

                ProgressBar(value: viewModel.progressPercent)
                    .frame(height: 10)
            }
        }
    }

    // MARK: - Expenses entry

    private func expensesEntryButton(voyageId: Int) -> some View {
        NavigationLink(value: ExpensesNavValue(voyageId: voyageId)) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.revOrange, .revRed],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Dépenses du voyage")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.revText)
                    Text("Suivi des comptes entre voyageurs")
                        .font(.system(size: 12))
                        .foregroundColor(.revTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.revOrange)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.revCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.revOrange.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: Color.revOrange.opacity(0.10), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Packing entry

    private func packingEntryButton(voyageId: Int) -> some View {
        NavigationLink(value: PackingNavValue(voyageId: voyageId)) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.revOrange, .revRed],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                    Image(systemName: "suitcase.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Liste de bagage")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.revText)
                    Text("Prépare ta valise avant le départ")
                        .font(.system(size: 12))
                        .foregroundColor(.revTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.revOrange)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.revCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.revOrange.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: Color.revOrange.opacity(0.10), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Étapes du voyage", systemImage: "list.bullet.rectangle")
                .padding(.horizontal, 4)

            if viewModel.etapes.isEmpty {
                GlassCard {
                    Text("Aucune étape n'a été ajoutée à ce voyage.")
                        .font(.system(size: 14))
                        .foregroundColor(.revTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            } else {
                ForEach(Array(viewModel.etapes.enumerated()), id: \.element.id) { index, etape in
                    NavigationLink(value: EtapeNavValue(etape: etape)) {
                        EtapeRow(
                            etape: etape,
                            isFirst: index == 0,
                            isLast: index == viewModel.etapes.count - 1,
                            isToggling: viewModel.togglingEtapeIds.contains(etape.id),
                            onToggle: { showToggleConfirmFor(etape) }
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if isAdmin, let voyage = viewModel.voyage {
                            Button {
                                adminSheet = AdminSheetItem(
                                    id: "edit-\(etape.id)-\(UUID())",
                                    mode: .edit(voyageId: voyage.id, etape: etape)
                                )
                            } label: {
                                Label("Modifier", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                pendingDeleteEtape = etape
                                showDeleteConfirm = true
                            } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private func showToggleConfirmFor(_ etape: VoyageEtape) {
        pendingToggleEtape = etape
        showToggleConfirm = true
    }

    private func maybeShowTripCompletedOverlay() {
        guard let voyage = viewModel.voyage else { return }
        guard viewModel.totalCount > 0 else { return }
        guard viewModel.completedCount == viewModel.totalCount else { return }

        let key = "trip_completed_overlay_seen_\(voyage.id)"
        if UserDefaults.standard.bool(forKey: key) { return }
        UserDefaults.standard.set(true, forKey: key)

        // Slight delay so the per-étape confetti has time to fire first
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeIn(duration: 0.3)) {
                showTripCompletedOverlay = true
            }
        }
    }

    private func handleToggle(_ etape: VoyageEtape) {
        let willComplete = !etape.is_completed
        Task { await viewModel.toggleEtape(etape) }

        if willComplete {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            confettiBurst += 1
            withAnimation { celebrate = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation { celebrate = false }
            }
        } else {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    private func firstGeoEtape() -> VoyageEtape? {
        let etapes = viewModel.voyage?.etapes ?? []
        if let withCoords = etapes.first(where: { $0.hasCoordinates }) {
            return withCoords
        }
        return etapes.first { ($0.adresse?.isEmpty == false) || ($0.lieu?.isEmpty == false) }
    }
}

// MARK: - Voyage hero — map + weather card for the destination

struct VoyageHero: View {
    let etape: VoyageEtape

    @State private var coordinate: CLLocationCoordinate2D? = nil
    @State private var region: MKCoordinateRegion = MKCoordinateRegion()
    @State private var weather: WeatherResponse? = nil
    @State private var weatherLoading: Bool = false
    @State private var locationLabel: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            if let coord = coordinate {
                Map(coordinateRegion: $region,
                    annotationItems: [HeroPin(coordinate: coord)]) { pin in
                    MapAnnotation(coordinate: pin.coordinate) {
                        ZStack {
                            Circle().fill(Color.revOrange).frame(width: 32, height: 32)
                                .shadow(radius: 6)
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 0))
                .allowsHitTesting(false)
            }

            WeatherCard(
                weather: weather,
                locationLabel: locationLabel,
                isLoading: weatherLoading
            )
            .padding(.horizontal, 18)
        }
        .task(id: etape.id) {
            await resolveAndLoad()
        }
    }

    private struct HeroPin: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
    }

    private func resolveAndLoad() async {
        // 1. Resolve coordinate (DB or geocode address fallback)
        var coord: CLLocationCoordinate2D? = nil
        if let lat = etape.latitude, let lng = etape.longitude {
            coord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        } else {
            let query = [etape.adresse, etape.lieu]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
            if !query.isEmpty {
                coord = await geocode(query)
            }
        }
        guard let c = coord else { return }
        coordinate = c
        region = MKCoordinateRegion(
            center: c,
            span: MKCoordinateSpan(latitudeDelta: 0.4, longitudeDelta: 0.4)
        )

        // 2. City label
        if let lieu = etape.lieu, !lieu.isEmpty {
            locationLabel = lieu
        } else {
            locationLabel = await reverseGeocode(c) ?? etape.titre
        }

        // 3. Weather
        weatherLoading = (weather == nil)
        do {
            weather = try await WeatherService.shared.fetch(latitude: c.latitude, longitude: c.longitude)
        } catch {
            #if DEBUG
            print("[VoyageHero] weather failed: \(error)")
            #endif
        }
        weatherLoading = false
    }

    private func geocode(_ query: String) async -> CLLocationCoordinate2D? {
        await withCheckedContinuation { cont in
            CLGeocoder().geocodeAddressString(query) { placemarks, _ in
                cont.resume(returning: placemarks?.first?.location?.coordinate)
            }
        }
    }

    private func reverseGeocode(_ coord: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        return await withCheckedContinuation { cont in
            CLGeocoder().reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "fr_FR")) { placemarks, _ in
                let pm = placemarks?.first
                cont.resume(returning: pm?.locality ?? pm?.subAdministrativeArea ?? pm?.administrativeArea)
            }
        }
    }
}

// MARK: - Étape row

struct EtapeRow: View {
    let etape: VoyageEtape
    let isFirst: Bool
    let isLast: Bool
    let isToggling: Bool
    let onToggle: () -> Void

    @State private var checkBounce: CGFloat = 1

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? Color.clear : Color.revOrange.opacity(0.3))
                    .frame(width: 2, height: 14)

                checkBubble

                Rectangle()
                    .fill(isLast ? Color.clear : Color.revOrange.opacity(0.3))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 30)

            etapeContent
                .padding(.bottom, isLast ? 0 : 12)
        }
    }

    private var checkBubble: some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.4)) {
                checkBounce = 1.4
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    checkBounce = 1
                }
            }
            onToggle()
        }) {
            ZStack {
                Circle()
                    .fill(etape.is_completed
                          ? AnyShapeStyle(LinearGradient(colors: [.revOrange, .revRed],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                          : AnyShapeStyle(Color.revCardBackground))
                    .overlay(
                        Circle()
                            .strokeBorder(etape.is_completed ? Color.clear : Color.revOrange.opacity(0.5),
                                          lineWidth: 2)
                    )
                    .frame(width: 30, height: 30)

                if isToggling {
                    ProgressView()
                        .tint(etape.is_completed ? .white : .revOrange)
                        .scaleEffect(0.6)
                } else if etape.is_completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: stepIcon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.revOrange)
                }
            }
            .scaleEffect(checkBounce)
            .shadow(color: etape.is_completed ? Color.revOrange.opacity(0.4) : .clear,
                    radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(isToggling)
    }

    private var stepIcon: String {
        switch etape.type {
        case "vol", "vol_aller", "vol_retour": return "airplane"
        case "hotel": return "bed.double.fill"
        case "activite": return "figure.walk"
        case "transfert": return "car.fill"
        case "restaurant": return "fork.knife"
        case "note": return "note.text"
        case "document": return "doc.fill"
        default: return "circle.fill"
        }
    }

    private var etapeContent: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(etape.titre)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(etape.is_completed ? .revTextSecondary : .revText)
                            .strikethrough(etape.is_completed)

                        if let lieu = etape.lieu, !lieu.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 10))
                                Text(lieu)
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.revTextSecondary)
                        }
                    }

                    Spacer()

                    if let date = etape.date?.toDate() {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "fr_BE"))))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.revOrange)
                            if let heure = etape.heure {
                                Text(heure)
                                    .font(.system(size: 10))
                                    .foregroundColor(.revTextSecondary)
                            }
                        }
                    }
                }

                if let description = etape.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.revTextSecondary)
                        .lineLimit(3)
                }

                if let cout = etape.cout, cout > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "eurosign.circle.fill")
                            .font(.system(size: 11))
                        Text(String(format: "%.0f €", cout))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.revOrange)
                }

                if etape.hasCoordinates,
                   let lat = etape.latitude, let lng = etape.longitude {
                    EtapeMiniMap(latitude: lat, longitude: lng,
                                 title: etape.titre, address: etape.adresse ?? etape.lieu)
                        .padding(.top, 6)
                }
            }
        }
        .opacity(etape.is_completed ? 0.75 : 1)
    }
}

struct EtapeMiniMap: View {
    let latitude: Double
    let longitude: Double
    let title: String
    let address: String?

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    @State private var region: MKCoordinateRegion
    @State private var showItinerarySheet = false

    init(latitude: Double, longitude: Double, title: String, address: String?) {
        self.latitude = latitude
        self.longitude = longitude
        self.title = title
        self.address = address
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Map(coordinateRegion: .constant(region),
                interactionModes: [],
                annotationItems: [MapPin(coordinate: coordinate)]) { pin in
                MapAnnotation(coordinate: pin.coordinate) {
                    ZStack {
                        Circle().fill(Color.revOrange).frame(width: 28, height: 28)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        Image(systemName: "mappin")
                            .foregroundColor(.white)
                            .font(.system(size: 13, weight: .bold))
                    }
                }
            }
            .frame(height: 110)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.gray.opacity(0.15), lineWidth: 1)
            )

            Button {
                showItinerarySheet = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.right.square.fill")
                        .font(.system(size: 11))
                    Text("Itinéraire")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.revOrange)
            }
        }
        .confirmationDialog("Ouvrir l'itinéraire avec", isPresented: $showItinerarySheet, titleVisibility: .visible) {
            Button("Apple Plans") { openInApplePlans() }
            Button("Google Maps") { openInGoogleMaps() }
            Button("Annuler", role: .cancel) {}
        }
    }

    private func openInApplePlans() {
        let placemark = MKPlacemark(coordinate: coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = title
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func openInGoogleMaps() {
        let appURL = URL(string: "comgooglemaps://?daddr=\(latitude),\(longitude)&directionsmode=driving")
        let webURL = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(latitude),\(longitude)&travelmode=driving")!
        if let appURL, UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else {
            UIApplication.shared.open(webURL)
        }
    }
}

private struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Progress bar

struct ProgressBar: View {
    let value: Double  // 0...1

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.15))

                Capsule()
                    .fill(LinearGradient(colors: [.revYellow, .revOrange, .revRed],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, geo.size.width * CGFloat(value)))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: value)
            }
        }
    }
}

// MARK: - Funny celebration overlay

struct CelebrationOverlay: View {
    let burst: Int
    @State private var particles: [Particle] = []

    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var color: Color
        var rotation: Double
        var scale: CGFloat
    }

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                Image(systemName: ["star.fill", "heart.fill", "sparkles", "airplane"].randomElement()!)
                    .font(.system(size: 22))
                    .foregroundColor(p.color)
                    .rotationEffect(.degrees(p.rotation))
                    .scaleEffect(p.scale)
                    .position(x: p.x, y: p.y)
            }
        }
        .ignoresSafeArea()
        .onChange(of: burst) { _ in spawn() }
        .onAppear { spawn() }
    }

    private func spawn() {
        let screen = UIScreen.main.bounds
        particles = (0..<18).map { _ in
            Particle(
                x: screen.width / 2 + CGFloat.random(in: -30...30),
                y: screen.height / 2,
                color: [.revYellow, .revOrange, .revRed].randomElement()!,
                rotation: Double.random(in: 0...360),
                scale: 0.4
            )
        }

        for i in particles.indices {
            let dx = CGFloat.random(in: -180...180)
            let dy = CGFloat.random(in: -300 ... -80)
            withAnimation(.easeOut(duration: 1.1)) {
                particles[i].x += dx
                particles[i].y += dy
                particles[i].rotation += Double.random(in: 180...720)
                particles[i].scale = CGFloat.random(in: 0.8...1.4)
            }
        }
    }
}

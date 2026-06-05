import SwiftUI
import MapKit
import QuickLook
import CoreLocation

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
    @State private var showMembersSheet: Bool = false
    /// Étape dont les infos sont présentées en feuille via le bouton « Infos »
    /// de la timeline (Feature 1), sans repush de NavigationLink.
    @State private var infosEtape: VoyageEtape? = nil

    // État de la carte récap billets (Feature 4).
    @State private var openingTicketId: String? = nil   // url du billet en cours d'ouverture
    @State private var recapImageURL: URL? = nil        // billet image plein écran
    @State private var recapQuickLookURL: URL? = nil    // billet PDF/doc téléchargé
    @State private var showRecapQuickLook: Bool = false

    // Localisation : invite d'arrivée à une étape (Feature 2, géoloc).
    @StateObject private var locationService = LocationService.shared
    @State private var arrivalEtape: VoyageEtape? = nil
    @State private var arrivalHandledIds: Set<Int> = []

    @Environment(\.dismiss) private var dismissVoyageDetail
    private let newTripDraft = "Bonjour ! Je viens de rentrer et j'aimerais préparer mon prochain voyage. Voici mes premières idées :\n\n• Destination envisagée : \n• Dates souhaitées : \n• Type de séjour : \n• Budget approximatif : \n\nMerci !"

    private struct AdminSheetItem: Identifiable {
        let id: String
        let mode: EtapeFormSheet.Mode
    }

    private var isAdmin: Bool {
        AuthService.shared.isAdmin
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
                            ticketsRecapCard(voyage: voyage)
                            membersEntryButton(voyageId: voyage.id)
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

            // Billet image (carte récap, Feature 4) en plein écran.
            if let url = recapImageURL {
                recapImageOverlay(url)
                    .zIndex(20)
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
        .sheet(isPresented: $showMembersSheet) {
            if let voyage = viewModel.voyage {
                VoyageMembersView(voyageId: voyage.id, owner: voyage.owner)
            }
        }
        // Détail d'étape ouvert via le bouton « Infos » de la timeline (Feature 1).
        .sheet(item: $infosEtape) { etape in
            if let voyage = viewModel.voyage {
                NavigationView {
                    EtapeDetailView(voyage: voyage, etape: etape, viewModel: viewModel)
                }
            }
        }
        // Billet PDF/document ouvert depuis la carte récap (Feature 4).
        .sheet(isPresented: $showRecapQuickLook) {
            if let url = recapQuickLookURL {
                EtapeTicketQuickLook(url: url)
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
        .onAppear { LocationService.shared.startIfPermitted() }
        .onChange(of: locationService.lastKnownLocation) { _ in checkArrival() }
        .onChange(of: viewModel.etapes.count) { _ in checkArrival() }
        .confirmationDialog(
            arrivalEtape.map { "Vous êtes arrivé à \($0.titre) ?" } ?? "",
            isPresented: Binding(
                get: { arrivalEtape != nil },
                set: { if !$0 { arrivalEtape = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let e = arrivalEtape {
                Button("Oui, marquer terminée") {
                    Task { await viewModel.toggleEtape(e) }
                    arrivalHandledIds.insert(e.id)
                    arrivalEtape = nil
                }
                Button("Pas encore", role: .cancel) {
                    arrivalHandledIds.insert(e.id)
                    arrivalEtape = nil
                }
            }
        } message: {
            if let e = arrivalEtape {
                Text(e.lieu.map { "Vous semblez être à proximité de \($0)." }
                    ?? "Vous semblez être à proximité de cette étape.")
            }
        }
    }

    /// Détecte l'arrivée à proximité (~200 m) d'une étape non terminée et propose
    /// de la cocher. Une étape déjà proposée n'est pas re-proposée dans la session.
    private func checkArrival() {
        guard arrivalEtape == nil else { return }
        guard let here = locationService.lastKnownLocation else { return }
        let radius: CLLocationDistance = 200
        var best: (etape: VoyageEtape, dist: CLLocationDistance)?
        for e in viewModel.etapes {
            guard !e.is_completed, !arrivalHandledIds.contains(e.id),
                  let lat = e.latitude, let lng = e.longitude else { continue }
            let d = here.distance(from: CLLocation(latitude: lat, longitude: lng))
            if d <= radius, best == nil || d < best!.dist {
                best = (e, d)
            }
        }
        if let b = best { arrivalEtape = b.etape }
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

    // MARK: - Tickets recap (Feature 4)

    /// Paire (billet, étape parente) pour la carte récap.
    private struct VoyageTicketRef: Identifiable {
        let ticket: EtapeTicket
        let etape: VoyageEtape
        var id: String { "\(etape.id)-\(ticket.url)" }
    }

    /// Tous les billets du voyage, à plat, avec leur étape parente.
    private func allVoyageTickets(_ voyage: Voyage) -> [VoyageTicketRef] {
        let etapes = viewModel.etapes.isEmpty ? (voyage.etapes ?? []) : viewModel.etapes
        return etapes.flatMap { etape in
            (etape.tickets ?? []).map { VoyageTicketRef(ticket: $0, etape: etape) }
        }
    }

    /// Carte récap listant TOUS les billets du voyage, tappables.
    /// Masquée si aucune étape n'a de billet.
    @ViewBuilder
    private func ticketsRecapCard(voyage: Voyage) -> some View {
        let refs = allVoyageTickets(voyage)
        if !refs.isEmpty {
            GlassCard(padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: "Tous les billets", systemImage: "ticket.fill")

                    VStack(spacing: 10) {
                        ForEach(refs) { ref in
                            Button {
                                openVoyageTicket(ref.ticket)
                            } label: {
                                HStack(spacing: 14) {
                                    // Visuel : photo de couverture de l'étape si
                                    // disponible, sinon icône du type d'étape.
                                    if let cover = ref.etape.coverImage,
                                       let coverURL = voyageTicketURL(cover) {
                                        CachedAsyncImage(url: coverURL) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                            default:
                                                ZStack {
                                                    Color.revOrange.opacity(0.12)
                                                    Image(systemName: EtapeTypeInfo.resolve(ref.etape.type).icon)
                                                        .font(.system(size: 20, weight: .semibold))
                                                        .foregroundColor(.revOrange)
                                                }
                                            }
                                        }
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    } else {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.revOrange.opacity(0.12))
                                                .frame(width: 44, height: 44)
                                            Image(systemName: EtapeTypeInfo.resolve(ref.etape.type).icon)
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundColor(.revOrange)
                                        }
                                    }

                                    // Nom de l'étape parente + passager attribué
                                    // (plus de nom de fichier / token affiché).
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(ref.etape.titre)
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundColor(.revText)
                                            .lineLimit(1)
                                        if let pax = ref.ticket.participant_name, !pax.isEmpty {
                                            HStack(spacing: 4) {
                                                Image(systemName: "person.fill")
                                                    .font(.system(size: 9, weight: .semibold))
                                                Text(pax)
                                                    .font(.system(size: 11, weight: .medium))
                                                    .lineLimit(1)
                                            }
                                            .foregroundColor(.revOrange)
                                        }
                                    }

                                    Spacer()

                                    if openingTicketId == ref.ticket.url {
                                        ProgressView().tint(.revOrange)
                                            .frame(width: 36, height: 36)
                                    } else {
                                        Image(systemName: "eye.fill")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.revOrange)
                                            .frame(width: 36, height: 36)
                                            .background(Circle().fill(Color.revOrange.opacity(0.12)))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(openingTicketId != nil)
                        }
                    }
                }
            }
        }
    }

    /// Construit l'URL absolue d'un billet (chemins relatifs ou absolus).
    private func voyageTicketURL(_ path: String) -> URL? {
        if path.hasPrefix("http") { return URL(string: path) }
        let base = APIConfig.baseURL.absoluteString.replacingOccurrences(of: "/api", with: "")
        return URL(string: base + (path.hasPrefix("/") ? path : "/" + path))
    }

    /// Ouvre un billet depuis la carte récap : image → overlay plein écran,
    /// PDF/doc → QuickLook (téléchargement local), repli Safari si échec.
    private func openVoyageTicket(_ ticket: EtapeTicket) {
        guard let url = voyageTicketURL(ticket.url) else { return }
        if ticket.is_image {
            withAnimation(.easeInOut(duration: 0.25)) { recapImageURL = url }
            return
        }
        guard openingTicketId == nil else { return }
        openingTicketId = ticket.url
        Task {
            do {
                let (localURL, _) = try await URLSession.shared.download(from: url)
                let ext = (url.lastPathComponent as NSString).pathExtension
                let dest = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(ext.isEmpty ? "pdf" : ext)
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.moveItem(at: localURL, to: dest)
                await MainActor.run {
                    openingTicketId = nil
                    recapQuickLookURL = dest
                    showRecapQuickLook = true
                }
            } catch {
                await MainActor.run {
                    openingTicketId = nil
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    /// Overlay plein écran d'un billet image (carte récap), avec pinch-to-zoom.
    private func recapImageOverlay(_ url: URL) -> some View {
        ZoomableImageView(url: url) {
            withAnimation(.easeInOut(duration: 0.25)) { recapImageURL = nil }
        }
        .transition(.opacity)
    }

    // MARK: - Members entry

    /// Ouvre la feuille de gestion des voyageurs / membres du voyage.
    /// Visible par tout le monde ; les actions d'invitation / retrait sont
    /// gérées (et gatées) à l'intérieur de `VoyageMembersView`.
    private func membersEntryButton(voyageId: Int) -> some View {
        Button {
            showMembersSheet = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.revOrange, .revRed],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Voyageurs / Membres")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.revText)
                    Text("Invite et gère les collaborateurs du voyage")
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
                    VStack(spacing: 0) {
                        NavigationLink(value: EtapeNavValue(etape: etape)) {
                            EtapeRow(
                                etape: etape,
                                isFirst: index == 0,
                                isLast: index == viewModel.etapes.count - 1,
                                isToggling: viewModel.togglingEtapeIds.contains(etape.id),
                                onToggle: { showToggleConfirmFor(etape) },
                                onOpenInfos: { infosEtape = currentEtape(etape) }
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

                        // Trajet inter-étapes (N → N+1) : affiché entre deux
                        // étapes consécutives, comme sur le web.
                        if index < viewModel.etapes.count - 1,
                           let cn = timelineConnector(for: etape) {
                            TimelineConnectorLabel(icon: cn.icon, text: cn.text)
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

    /// Construit le label de trajet inter-étapes (mode de transport +
    /// distance · durée) à partir des champs connector_* de l'étape.
    /// Renvoie nil si aucune info de trajet n'est disponible.
    private func timelineConnector(for etape: VoyageEtape) -> (icon: String, text: String)? {
        let mode = etape.connector_mode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let duration = etape.connector_duration?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let distanceRaw = etape.connector_distance?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // L'API peut renvoyer "1061 km · " avec un séparateur résiduel.
        let distance = distanceRaw.trimmingCharacters(in: CharacterSet(charactersIn: " ·"))
        guard !mode.isEmpty || !duration.isEmpty || !distance.isEmpty else { return nil }

        let map: (icon: String, label: String)
        switch mode.lowercased() {
        case "car": map = ("car.fill", "Voiture")
        case "train": map = ("tram.fill", "Train")
        case "plane": map = ("airplane", "Avion")
        case "bus": map = ("bus.fill", "Bus")
        case "navette": map = ("bus.fill", "Navette")
        case "taxi": map = ("car.fill", "Taxi")
        case "walk": map = ("figure.walk", "À pied")
        default: map = ("arrow.right.circle.fill", "Trajet")
        }

        var parts: [String] = [map.label]
        if !distance.isEmpty { parts.append(distance) }
        if !duration.isEmpty { parts.append(duration) }
        return (icon: map.icon, text: parts.joined(separator: " · "))
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

    /// Étape sur laquelle centrer la carte « hero ».
    /// Suit la progression du voyage en temps réel : on cible la première étape
    /// NON terminée qui possède des coordonnées (= là où l'on en est). Une fois
    /// une étape cochée (ex. le vol de départ), la carte avance d'elle-même vers
    /// la suivante. Si tout est terminé, on retombe sur la dernière étape géolocalisée.
    private func firstGeoEtape() -> VoyageEtape? {
        // Source VIVANTE : `viewModel.etapes` est mis à jour de façon optimiste à
        // chaque cochage (contrairement à `voyage.etapes` qui reste figé jusqu'au
        // prochain load). C'est ce qui permet à la carte d'avancer immédiatement.
        let etapes = viewModel.etapes
        // 1. Première étape non terminée avec coordonnées (progression « temps réel »).
        if let current = etapes.first(where: { !$0.is_completed && $0.hasCoordinates }) {
            return current
        }
        // 2. Tout est coché : on montre la dernière étape géolocalisée atteinte.
        if let last = etapes.last(where: { $0.hasCoordinates }) {
            return last
        }
        // 3. Aucune coordonnée : on garde une étape adressable pour le géocodage.
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
                    interactionModes: [],
                    showsUserLocation: true,
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
    /// Ouvre le détail de l'étape (bouton « Infos »). Câblé par le parent.
    var onOpenInfos: () -> Void = {}

    @State private var checkBounce: CGFloat = 1

    // État pour l'ouverture directe d'un billet (Feature 1), sans passer
    // par le détail de l'étape. Réutilise QuickLook (PDF/doc) et un overlay
    // plein écran (image), à l'image de EtapeDetailView.
    @State private var fullScreenImageURL: URL? = nil
    @State private var quickLookURL: URL? = nil
    @State private var showQuickLook: Bool = false
    @State private var isOpeningTicket: Bool = false

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
        // Overlay plein écran pour un billet image ouvert depuis la timeline.
        .overlay {
            if let url = fullScreenImageURL {
                ticketImageOverlay(url)
            }
        }
        // QuickLook pour un billet PDF/document ouvert depuis la timeline.
        .sheet(isPresented: $showQuickLook) {
            if let fileURL = quickLookURL {
                EtapeTicketQuickLook(url: fileURL)
            }
        }
    }

    // MARK: - Feature 1 : boutons rapides (billet / infos)

    /// Petites puces tappables affichées dans la ligne de timeline.
    /// - « Billet » : ouvre directement le premier billet de l'étape.
    /// - « Infos »  : ouvre le détail de l'étape (callback parent).
    /// Affichées uniquement si l'étape a un billet et/ou une note.
    @ViewBuilder
    private var quickActionChips: some View {
        let firstTicket = etape.tickets?.first
        let hasNote = !etape.notePreview.isEmpty
        if firstTicket != nil || hasNote {
            HStack(spacing: 8) {
                if let ticket = firstTicket {
                    Button {
                        openTicket(ticket)
                    } label: {
                        HStack(spacing: 4) {
                            if isOpeningTicket {
                                ProgressView()
                                    .tint(.revOrange)
                                    .scaleEffect(0.6)
                            } else {
                                Image(systemName: "ticket.fill")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            Text("Billet")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.revOrange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.revOrange.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .disabled(isOpeningTicket)
                }

                if hasNote {
                    Button {
                        onOpenInfos()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Infos")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.revBrown)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.revYellow.opacity(0.25)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 2)
        }
    }

    /// Construit l'URL absolue d'un billet (gère chemins relatifs et absolus).
    private func ticketURL(_ path: String) -> URL? {
        if path.hasPrefix("http") { return URL(string: path) }
        let base = APIConfig.baseURL.absoluteString.replacingOccurrences(of: "/api", with: "")
        return URL(string: base + (path.hasPrefix("/") ? path : "/" + path))
    }

    /// Ouvre un billet : image → overlay plein écran ; PDF/doc → QuickLook
    /// (téléchargement local puis prévisualisation), repli Safari si échec.
    private func openTicket(_ ticket: EtapeTicket) {
        guard let url = ticketURL(ticket.url) else { return }
        if ticket.is_image {
            withAnimation(.easeInOut(duration: 0.25)) { fullScreenImageURL = url }
            return
        }
        guard !isOpeningTicket else { return }
        isOpeningTicket = true
        Task {
            do {
                let (localURL, _) = try await URLSession.shared.download(from: url)
                let ext = (url.lastPathComponent as NSString).pathExtension
                let dest = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(ext.isEmpty ? "pdf" : ext)
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.moveItem(at: localURL, to: dest)
                await MainActor.run {
                    isOpeningTicket = false
                    quickLookURL = dest
                    showQuickLook = true
                }
            } catch {
                await MainActor.run {
                    isOpeningTicket = false
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    /// Overlay plein écran d'un billet image, avec pinch-to-zoom.
    private func ticketImageOverlay(_ url: URL) -> some View {
        ZoomableImageView(url: url) {
            withAnimation(.easeInOut(duration: 0.25)) { fullScreenImageURL = nil }
        }
        .transition(.opacity)
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

    // Icône du type d'étape via la source unique partagée (cf. EtapeTypeInfo).
    private var stepIcon: String { EtapeTypeInfo.resolve(etape.type).icon }

    /// Construit l'URL absolue d'une couverture (gère chemins relatifs et absolus).
    private func etapeCoverURL(_ path: String) -> URL? {
        if path.hasPrefix("http") { return URL(string: path) }
        let base = APIConfig.baseURL.absoluteString.replacingOccurrences(of: "/api", with: "")
        return URL(string: base + (path.hasPrefix("/") ? path : "/" + path))
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

                    // Badge billet : signale qu'au moins un ticket est attaché.
                    if etape.hasTickets {
                        Image(systemName: "ticket.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.revOrange)
                            .padding(.trailing, 2)
                    }

                    if let date = etape.date?.toDate() {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "fr_BE"))))
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.revOrange)
                            // Heure optionnelle : on n'affiche la ligne que si une
                            // heure non vide est réellement présente (Feature 2).
                            if let heure = etape.heure?.trimmingCharacters(in: .whitespaces),
                               !heure.isEmpty {
                                Text(heure)
                                    .font(.system(size: 10))
                                    .foregroundColor(.revTextSecondary)
                            }
                        }
                    }
                }

                // Aperçu de la note : on privilégie la description en texte brut,
                // sinon on retombe sur contenu_html nettoyé de ses balises HTML
                // (sinon les étapes dont le contenu n'existe que dans contenu_html
                //  — ex. notes saisies via l'éditeur riche web — n'affichaient rien).
                if !etape.notePreview.isEmpty {
                    Text(etape.notePreview)
                        .font(.system(size: 12))
                        .foregroundColor(.revTextSecondary)
                        .lineLimit(3)
                }

                // Boutons rapides (Feature 1) : ouvrent directement le billet
                // ou les infos sans devoir d'abord ouvrir le détail de l'étape.
                quickActionChips

                if let cout = etape.cout, cout > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "eurosign.circle.fill")
                            .font(.system(size: 11))
                        Text(String(format: "%.0f €", cout))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.revOrange)
                }

                // Visuel de l'étape : si une image de couverture existe, on
                // l'affiche à la place de la mini-carte (même taille/emplacement).
                // Sinon on retombe sur la mini-carte quand on a des coordonnées.
                if let cover = etape.coverImage,
                   let coverURL = etapeCoverURL(cover) {
                    EtapeCoverThumb(url: coverURL)
                        .padding(.top, 6)
                } else if etape.hasCoordinates,
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

/// Petit label de trajet inter-étapes affiché dans la timeline, entre
/// deux étapes consécutives (icône transport + mode · distance · durée).
struct TimelineConnectorLabel: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .foregroundColor(.revTextSecondary)
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Capsule().fill(Color.revOrange.opacity(0.10)))
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 4)
    }
}

/// Vignette de couverture d'une étape affichée dans la timeline,
/// calibrée sur la même taille/forme que `EtapeMiniMap`.
struct EtapeCoverThumb: View {
    let url: URL

    var body: some View {
        CachedAsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                ZStack {
                    Color.revCardBackground
                    Image(systemName: "photo")
                        .font(.system(size: 22))
                        .foregroundColor(.revTextSecondary)
                }
            case .empty:
                ZStack {
                    Color.revCardBackground
                    ProgressView().tint(.revOrange)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.gray.opacity(0.15), lineWidth: 1)
        )
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
                showsUserLocation: true,
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

// MARK: - QuickLook (prévisualisation d'un billet PDF/document)

/// Petit wrapper QLPreviewController réutilisé pour ouvrir un billet
/// directement depuis la timeline ou la carte récap (Features 1 & 4).
/// (Distinct du `QuickLookPreview` privé de EtapeDetailView.)
struct EtapeTicketQuickLook: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as QLPreviewItem
        }
    }
}

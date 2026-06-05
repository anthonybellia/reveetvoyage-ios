import SwiftUI
import MapKit
import QuickLook
import PDFKit
import Photos

/// Detail full-screen for a single voyage étape.
/// - Big interactive map if coordinates
/// - Itinerary action sheet (Apple Plans / Google Maps)
/// - All metadata (date, time, lieu, adresse, compagnie, ref, prix, description)
/// - Toggle "Marquer comme effectuée" with confirmation
struct EtapeDetailView: View {
    let voyage: Voyage
    let etape: VoyageEtape
    @ObservedObject var viewModel: VoyageDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showItinerarySheet: Bool = false
    @State private var showToggleConfirm: Bool = false
    @State private var region: MKCoordinateRegion = MKCoordinateRegion()
    @State private var resolvedCoordinate: CLLocationCoordinate2D? = nil
    @State private var isGeocoding: Bool = false

    // Attachments state
    @State private var fullScreenImageURL: URL? = nil
    @State private var isDownloading: Bool = false
    @State private var downloadedFileURL: URL? = nil
    @State private var showShareSheet: Bool = false
    @State private var showImageSaveSuccess: Bool = false
    @State private var showQuickLook: Bool = false

    // Admin state
    @State private var showEditSheet: Bool = false
    @State private var showDeleteConfirm: Bool = false

    private var isAdmin: Bool {
        AuthService.shared.isAdmin
    }

    private var mapCoordinate: CLLocationCoordinate2D? {
        if let lat = etape.latitude, let lng = etape.longitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        return resolvedCoordinate
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let coord = mapCoordinate {
                    mapHero(coord)
                } else if isGeocoding {
                    geocodingPlaceholder
                }

                headerCard
                    .padding(.horizontal, 18)

                if !infoRows.isEmpty {
                    infoCard
                        .padding(.horizontal, 18)
                }

                // Description riche : on privilégie le HTML de l'éditeur (contenu_html),
                // sinon on retombe sur la description en texte brut.
                if let html = etape.contenu_html, !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    descriptionCard(html: html)
                        .padding(.horizontal, 18)
                } else if let description = etape.description, !description.isEmpty {
                    descriptionCard(text: description)
                        .padding(.horizontal, 18)
                }

                if etape.hasAttachments {
                    attachmentsSection
                        .padding(.horizontal, 18)
                }

                actionsRow
                    .padding(.horizontal, 18)
                    .padding(.top, 4)

                Spacer(minLength: 30)
            }
        }
        .background(Color.revBackground.ignoresSafeArea())
        .navigationTitle("Étape \(etape.ordre)")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            etape.is_completed
                ? "Marquer cette étape comme non effectuée ?"
                : "As-tu bien réalisé cette étape ?",
            isPresented: $showToggleConfirm,
            titleVisibility: .visible
        ) {
            Button(etape.is_completed ? "Marquer non effectuée" : "Oui, c'est fait ✅",
                   role: etape.is_completed ? .destructive : nil) {
                Task { await viewModel.toggleEtape(etape) }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            if !etape.is_completed {
                Text("Tu peux passer à l'étape suivante. On te rappellera les prochaines automatiquement.")
            }
        }
        .confirmationDialog(
            "Ouvrir l'itinéraire avec",
            isPresented: $showItinerarySheet,
            titleVisibility: .visible
        ) {
            if let coord = mapCoordinate {
                Button("Apple Plans") { openInApplePlans(lat: coord.latitude, lng: coord.longitude) }
                Button("Google Maps") { openInGoogleMaps(lat: coord.latitude, lng: coord.longitude) }
                Button("Annuler", role: .cancel) {}
            }
        }
        .onAppear { initializeMap() }
        .overlay {
            if let url = fullScreenImageURL {
                fullScreenImageOverlay(url)
            }
        }
        .overlay {
            if showImageSaveSuccess {
                imageSaveToast
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let fileURL = downloadedFileURL {
                ShareSheet(items: [fileURL])
            }
        }
        .sheet(isPresented: $showQuickLook) {
            if let fileURL = downloadedFileURL {
                QuickLookPreview(url: fileURL)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EtapeFormSheet(mode: .edit(voyageId: voyage.id, etape: etape)) { saved in
                viewModel.upsertEtape(saved)
            }
        }
        .confirmationDialog(
            "Supprimer cette étape ?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                Task {
                    await viewModel.deleteEtape(etape)
                    dismiss()
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("\(etape.titre) sera supprimée définitivement.")
        }
        .toolbar {
            if isAdmin {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("Modifier", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundColor(.revOrange)
                    }
                }
            }
        }
    }

    private func initializeMap() {
        if let lat = etape.latitude, let lng = etape.longitude {
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
            return
        }

        let candidate = [etape.adresse, etape.lieu]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        guard !candidate.isEmpty else { return }

        isGeocoding = true
        CLGeocoder().geocodeAddressString(candidate) { placemarks, _ in
            DispatchQueue.main.async {
                isGeocoding = false
                guard let loc = placemarks?.first?.location else { return }
                resolvedCoordinate = loc.coordinate
                region = MKCoordinateRegion(
                    center: loc.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            }
        }
    }

    // MARK: - Map

    private func mapHero(_ coord: CLLocationCoordinate2D) -> some View {
        ZStack(alignment: .topLeading) {
            Map(coordinateRegion: $region,
                interactionModes: [],
                showsUserLocation: true,
                annotationItems: [Pin(coordinate: coord)]) { p in
                MapAnnotation(coordinate: p.coordinate) {
                    ZStack {
                        Circle().fill(Color.revOrange).frame(width: 36, height: 36)
                            .shadow(radius: 6)
                        Image(systemName: stepIcon)
                            .foregroundColor(.white).font(.system(size: 16, weight: .bold))
                    }
                }
            }
            .frame(height: 220)
            .ignoresSafeArea(edges: .top)

            // floating type badge
            HStack(spacing: 6) {
                Image(systemName: stepIcon).font(.system(size: 11, weight: .semibold))
                Text(typeLabel.uppercased()).font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(Color.revBrownDark.opacity(0.8)))
            .padding(.top, 18).padding(.leading, 16)
        }
    }

    private var geocodingPlaceholder: some View {
        ZStack {
            Rectangle()
                .fill(Color.revBackground)
                .frame(height: 220)
                .overlay(
                    LinearGradient(
                        colors: [Color.revYellow.opacity(0.15), Color.revOrange.opacity(0.08)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            VStack(spacing: 8) {
                ProgressView().tint(.revOrange)
                Text("Localisation de l'étape…")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.revTextSecondary)
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    private struct Pin: Identifiable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
    }

    // MARK: - Header card

    private var headerCard: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(etape.titre)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.revText)
                        if let lieu = etape.lieu, !lieu.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 12)).foregroundColor(.revOrange)
                                Text(lieu).font(.system(size: 13))
                                    .foregroundColor(.revTextSecondary)
                            }
                        }
                    }
                    Spacer()
                    if etape.is_completed {
                        Label("Effectuée", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().fill(Color.green.opacity(0.15)))
                    }
                }
            }
        }
    }

    // MARK: - Info card

    private var infoRows: [(icon: String, label: String, value: String)] {
        var rows: [(String, String, String)] = []
        if let date = etape.date?.toDate() {
            rows.append(("calendar", "Date", date.formatted(style: .long)))
        }
        if let h = etape.heure, !h.isEmpty {
            rows.append(("clock.fill", "Heure", h))
        }
        if let hr = etape.heure_retour, !hr.isEmpty {
            rows.append(("arrow.uturn.backward", "Heure retour", hr))
        }
        // Trajet inter-étapes : mode de transport + durée · distance
        if let transport = connectorInfo {
            rows.append(transport)
        }
        if let adresse = etape.adresse, !adresse.isEmpty {
            rows.append(("location.fill", "Adresse", adresse))
        }
        if let lieuRetour = etape.lieu_retour, !lieuRetour.isEmpty {
            rows.append(("arrow.left.and.right", "Lieu de retour", lieuRetour))
        }
        if let compagnie = etape.compagnie, !compagnie.isEmpty {
            rows.append(("building.2.fill", "Compagnie / Hôtel", compagnie))
        }
        if let ref = etape.numero_ref, !ref.isEmpty {
            rows.append(("number.circle.fill", "Référence", ref))
        }
        if let cout = etape.cout, cout > 0 {
            rows.append(("eurosign.circle.fill", "Coût", String(format: "%.0f €", cout)))
        }
        return rows.map { (icon: $0.0, label: $0.1, value: $0.2) }
    }

    // Construit la ligne "Transport" à partir des champs connector_* de l'API.
    // Renvoie nil si aucune info de trajet n'est disponible.
    private var connectorInfo: (icon: String, label: String, value: String)? {
        let mode = etape.connector_mode?.trimmingCharacters(in: .whitespacesAndNewlines)
        let duration = etape.connector_duration?.trimmingCharacters(in: .whitespacesAndNewlines)
        let distance = etape.connector_distance?.trimmingCharacters(in: .whitespacesAndNewlines)

        let hasMode = !(mode ?? "").isEmpty
        let hasDuration = !(duration ?? "").isEmpty
        let hasDistance = !(distance ?? "").isEmpty
        guard hasMode || hasDuration || hasDistance else { return nil }

        let mapping = transportMapping(for: mode)

        // Valeur : "1h25 · 1061 km" (on nettoie les séparateurs résiduels de l'API).
        var parts: [String] = []
        if hasDuration { parts.append(duration!) }
        if hasDistance {
            // L'API peut renvoyer "1061 km · " avec un séparateur en trop.
            let cleaned = distance!.trimmingCharacters(in: CharacterSet(charactersIn: " ·"))
            if !cleaned.isEmpty { parts.append(cleaned) }
        }
        let value = parts.isEmpty ? mapping.label : parts.joined(separator: " · ")

        return (icon: mapping.icon, label: "Transport — \(mapping.label)", value: value)
    }

    // Associe un mode de transport (API) à un SF Symbol + libellé français.
    private func transportMapping(for mode: String?) -> (icon: String, label: String) {
        switch mode?.lowercased() {
        case "car": return ("car.fill", "Voiture")
        case "train": return ("tram.fill", "Train")
        case "plane": return ("airplane", "Avion")
        case "bus": return ("bus.fill", "Bus")
        case "navette": return ("bus.fill", "Navette")
        case "taxi": return ("car.fill", "Taxi")
        case "walk": return ("figure.walk", "À pied")
        default: return ("arrow.right.circle.fill", "Trajet")
        }
    }

    private var infoCard: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: "Détails", systemImage: "info.circle.fill")
                ForEach(Array(infoRows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: row.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.revOrange)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.revTextSecondary)
                            Text(row.value)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.revText)
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    // Carte "Notes" en texte brut (fallback quand contenu_html est absent).
    private func descriptionCard(text: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "Notes", systemImage: "note.text")
                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(.revText)
            }
        }
    }

    // Carte "Notes" rendue à partir du HTML de l'éditeur riche (contenu_html).
    private func descriptionCard(html: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "Notes", systemImage: "note.text")
                HTMLText(html: html)
            }
        }
    }

    // MARK: - Actions

    private var actionsRow: some View {
        VStack(spacing: 10) {
            if mapCoordinate != nil {
                BrandButton(title: "Itinéraire", systemImage: "arrow.triangle.turn.up.right.diamond.fill",
                            style: .primary) {
                    showItinerarySheet = true
                }
            }
            BrandButton(
                title: etape.is_completed ? "Marquer non effectuée" : "Marquer comme effectuée",
                systemImage: etape.is_completed ? "arrow.uturn.backward" : "checkmark.circle.fill",
                isLoading: viewModel.togglingEtapeIds.contains(etape.id),
                style: etape.is_completed ? .ghost : .secondary
            ) {
                showToggleConfirm = true
            }
        }
    }

    // MARK: - Attachments

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Images gallery (combines legacy `image` + new `images` array)
            let allImages = etape.allImages
            if !allImages.isEmpty {
                GlassCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(title: "Photos", systemImage: "photo.stack")

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(allImages.enumerated()), id: \.offset) { _, urlString in
                                    if let url = attachmentURL(urlString) {
                                        imageThumb(url)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Document fichier
            if let fichier = etape.fichier, let url = attachmentURL(fichier) {
                GlassCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(title: "Document", systemImage: "doc.fill")

                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.revOrange.opacity(0.12))
                                    .frame(width: 48, height: 48)
                                Image(systemName: documentIcon(for: fichier))
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(.revOrange)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(documentName(from: fichier))
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.revText)
                                    .lineLimit(1)
                                Text(documentExtension(from: fichier).uppercased())
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.revTextSecondary)
                            }

                            Spacer()

                            // Open/Preview button
                            Button {
                                openDocument(url)
                            } label: {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.revOrange)
                                    .frame(width: 40, height: 40)
                                    .background(Circle().fill(Color.revOrange.opacity(0.12)))
                            }

                            // Download button
                            Button {
                                downloadFile(from: url)
                            } label: {
                                ZStack {
                                    if isDownloading {
                                        ProgressView()
                                            .tint(.revOrange)
                                            .frame(width: 40, height: 40)
                                    } else {
                                        Image(systemName: "arrow.down.circle.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .frame(width: 40, height: 40)
                                            .background(
                                                Circle().fill(
                                                    LinearGradient(
                                                        colors: [.revOrange, .revRed],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                            )
                                    }
                                }
                            }
                            .disabled(isDownloading)
                        }
                    }
                }
            }

            // Billets / Tickets attachés à l'étape (PDF, image…).
            if let tickets = etape.tickets, !tickets.isEmpty {
                GlassCard(padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(title: "Billets / Tickets", systemImage: "ticket.fill")

                        VStack(spacing: 10) {
                            ForEach(tickets) { ticket in
                                ticketRow(ticket)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Billet : ligne cliquable + aperçu inline (image ou 1ʳᵉ page PDF) en dessous.
    private func ticketRow(_ ticket: EtapeTicket) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ticketRowHeader(ticket)

            if let url = attachmentURL(ticket.url) {
                if ticket.is_image {
                    inlineImagePreview(url)
                } else if ticket.is_pdf {
                    PDFThumbnailInline(url: url)
                        .onTapGesture { openDocument(url) }
                }
                // Autre type : aucun aperçu, la ligne cliquable suffit.
            }
        }
    }

    /// Ligne d'un billet : icône selon le type, tap pour ouvrir/prévisualiser.
    private func ticketRowHeader(_ ticket: EtapeTicket) -> some View {
        Button {
            guard let url = attachmentURL(ticket.url) else { return }
            if ticket.is_image {
                // Aperçu plein écran via le visualiseur d'images existant.
                withAnimation(.easeInOut(duration: 0.25)) {
                    fullScreenImageURL = url
                }
            } else {
                // PDF / autres documents : on réutilise le mécanisme QuickLook.
                openDocument(url)
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.revOrange.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: ticketIcon(for: ticket))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.revOrange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(ticket.name.isEmpty ? documentName(from: ticket.url) : ticket.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.revText)
                        .lineLimit(1)
                    Text(ticket.ext.uppercased())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.revTextSecondary)
                    if let pax = ticket.participant_name, !pax.isEmpty {
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

                Image(systemName: "eye.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.revOrange)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.revOrange.opacity(0.12)))
            }
        }
        .buttonStyle(.plain)
    }

    /// Aperçu image inline d'un billet (sous la ligne). Tap → plein écran.
    private func inlineImagePreview(_ url: URL) -> some View {
        CachedAsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            fullScreenImageURL = url
                        }
                    }
            case .failure:
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.revCardBackground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                    Image(systemName: "photo")
                        .font(.system(size: 28))
                        .foregroundColor(.revTextSecondary)
                }
            case .empty:
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.revCardBackground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                    ProgressView().tint(.revOrange)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
    }

    /// Icône d'un billet : pdf → `doc.fill`, image → `photo`, sinon `doc.fill`.
    private func ticketIcon(for ticket: EtapeTicket) -> String {
        if ticket.is_pdf { return "doc.fill" }
        if ticket.is_image { return "photo" }
        return "doc.fill"
    }

    private func imageThumb(_ url: URL) -> some View {
        CachedAsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 140, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            fullScreenImageURL = url
                        }
                    }
                    .onLongPressGesture {
                        saveImageToPhotos(from: url)
                    }
            case .failure:
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.revCardBackground)
                        .frame(width: 140, height: 100)
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundColor(.revTextSecondary)
                }
            case .empty:
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.revCardBackground)
                        .frame(width: 140, height: 100)
                    ProgressView().tint(.revOrange)
                }
            }
        }
        .frame(width: 140, height: 100)
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
    }

    private func fullScreenImageOverlay(_ url: URL) -> some View {
        ZoomableImageView(url: url) {
            withAnimation(.easeInOut(duration: 0.25)) { fullScreenImageURL = nil }
        }
        .transition(.opacity)
    }

    private var imageSaveToast: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Photo enregistree")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Capsule().fill(Color.revBrownDark.opacity(0.9)))
            .padding(.bottom, 40)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .allowsHitTesting(false)
    }

    // MARK: - Attachment Helpers

    private func attachmentURL(_ path: String) -> URL? {
        if path.hasPrefix("http") { return URL(string: path) }
        let base = APIConfig.baseURL.absoluteString.replacingOccurrences(of: "/api", with: "")
        return URL(string: base + (path.hasPrefix("/") ? path : "/" + path))
    }

    private func documentIcon(for path: String) -> String {
        let ext = documentExtension(from: path).lowercased()
        switch ext {
        case "pdf": return "doc.richtext.fill"
        case "doc", "docx": return "doc.text.fill"
        case "xls", "xlsx": return "tablecells.fill"
        default: return "doc.fill"
        }
    }

    private func documentName(from path: String) -> String {
        (path as NSString).lastPathComponent
    }

    private func documentExtension(from path: String) -> String {
        (path as NSString).pathExtension
    }

    private func openDocument(_ url: URL) {
        Task {
            do {
                let (localURL, _) = try await URLSession.shared.download(from: url)
                let ext = documentExtension(from: url.lastPathComponent)
                let dest = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(ext.isEmpty ? "pdf" : ext)
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.moveItem(at: localURL, to: dest)
                await MainActor.run {
                    downloadedFileURL = dest
                    showQuickLook = true
                }
            } catch {
                // Fallback: open in Safari
                await MainActor.run {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    private func downloadFile(from url: URL) {
        guard !isDownloading else { return }
        isDownloading = true
        Task {
            do {
                let (localURL, _) = try await URLSession.shared.download(from: url)
                let ext = documentExtension(from: url.lastPathComponent)
                let fileName = documentName(from: url.lastPathComponent)
                let dest = FileManager.default.temporaryDirectory
                    .appendingPathComponent(fileName.isEmpty ? "document.\(ext)" : fileName)
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.moveItem(at: localURL, to: dest)
                await MainActor.run {
                    isDownloading = false
                    downloadedFileURL = dest
                    showShareSheet = true
                }
            } catch {
                await MainActor.run {
                    isDownloading = false
                }
            }
        }
    }

    private func saveImageToPhotos(from url: URL) {
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let uiImage = UIImage(data: data) else { return }
                await MainActor.run {
                    UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
                    withAnimation(.spring(response: 0.4)) {
                        showImageSaveSuccess = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeOut) {
                            showImageSaveSuccess = false
                        }
                    }
                }
            } catch {
                // Silent failure — network issue
            }
        }
    }

    // MARK: - Helpers

    // Icône + libellé du type d'étape via la source unique partagée.
    private var stepIcon: String { EtapeTypeInfo.resolve(etape.type).icon }
    private var typeLabel: String { EtapeTypeInfo.resolve(etape.type).label }

    private func openInApplePlans(lat: Double, lng: Double) {
        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coord))
        item.name = etape.titre
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func openInGoogleMaps(lat: Double, lng: Double) {
        // comgooglemaps:// scheme if installed, else fallback web URL
        let appURL = URL(string: "comgooglemaps://?daddr=\(lat),\(lng)&directionsmode=driving")
        let webURL = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(lat),\(lng)&travelmode=driving")!
        if let appURL, UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else {
            UIApplication.shared.open(webURL)
        }
    }
}

// MARK: - ShareSheet (UIActivityViewController wrapper)

// MARK: - QuickLook Preview (QLPreviewController wrapper)

private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as QLPreviewItem
        }
    }
}

// MARK: - HTMLText (rendu du HTML de l'éditeur riche en texte formaté)

/// Affiche une chaîne HTML sous forme de texte formaté (gras, listes, liens…).
/// Réutilisable partout où l'API renvoie un champ `contenu_html`.
///
/// Le parsing NSAttributedString(documentType: .html) DOIT s'exécuter sur le
/// main thread (UIKit). On garde donc le rendu synchrone ici (les notes
/// d'étapes sont courtes). En cas d'échec de parsing, on retombe sur le texte
/// brut nettoyé de ses balises.
struct HTMLText: View {
    let html: String

    var body: some View {
        Text(attributed)
            .font(.system(size: 14))
            .foregroundColor(.revText)
            .tint(.revOrange) // couleur des liens
            .fixedSize(horizontal: false, vertical: true)
    }

    private var attributed: AttributedString {
        // On enrobe le HTML pour forcer la police/taille de base (sinon Times 12pt par défaut).
        let styled = """
        <style>
        body { font-family: -apple-system, sans-serif; font-size: 14px; }
        </style>
        \(html)
        """

        guard let data = styled.data(using: .utf8) else {
            return AttributedString(strippedPlainText)
        }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        if let ns = try? NSAttributedString(data: data, options: options, documentAttributes: nil),
           let converted = try? AttributedString(ns, including: \.swiftUI) {
            return converted
        }

        // Repli : texte brut débarrassé de ses balises HTML.
        return AttributedString(strippedPlainText)
    }

    // Supprime grossièrement les balises HTML pour le fallback.
    private var strippedPlainText: String {
        html
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - PDFThumbnailInline (aperçu de la 1ʳᵉ page d'un PDF distant)

/// Télécharge un PDF distant, rend sa 1ʳᵉ page en image et l'affiche inline.
/// États gérés : chargement (ProgressView), succès (thumbnail), échec (icône doc).
/// Le tap est géré par la vue parente (ouverture QuickLook).
private struct PDFThumbnailInline: View {
    let url: URL

    @State private var image: UIImage? = nil
    @State private var didFail: Bool = false

    private let maxHeight: CGFloat = 260

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: maxHeight)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "doc.richtext.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Circle().fill(Color.revBrownDark.opacity(0.75)))
                            .padding(8)
                    }
            } else if didFail {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.revCardBackground)
                        .frame(maxWidth: .infinity)
                        .frame(height: maxHeight)
                    Image(systemName: "doc.richtext.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.revTextSecondary)
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.revCardBackground)
                        .frame(maxWidth: .infinity)
                        .frame(height: maxHeight)
                    ProgressView().tint(.revOrange)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: maxHeight)
        .task(id: url) {
            await loadThumbnail()
        }
    }

    /// Télécharge le PDF puis rend sa 1ʳᵉ page hors du main thread.
    private func loadThumbnail() async {
        // Évite de retélécharger si déjà chargé (ré-exécution de .task).
        if image != nil { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let rendered = Self.renderFirstPage(from: data, maxHeight: maxHeight)
            await MainActor.run {
                if let rendered {
                    self.image = rendered
                } else {
                    self.didFail = true
                }
            }
        } catch {
            await MainActor.run {
                self.didFail = true
            }
        }
    }

    /// Rend la 1ʳᵉ page d'un PDF en `UIImage`. `nil` si le document est invalide.
    private static func renderFirstPage(from data: Data, maxHeight: CGFloat) -> UIImage? {
        guard let document = PDFDocument(data: data),
              let page = document.page(at: 0) else { return nil }

        let pageRect = page.bounds(for: .mediaBox)
        guard pageRect.width > 0, pageRect.height > 0 else { return nil }

        // On rend à une échelle correspondant à la hauteur d'affichage (Retina x2).
        let scale = (maxHeight * 2) / pageRect.height
        let targetSize = CGSize(width: pageRect.width * scale,
                                height: pageRect.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(CGRect(origin: .zero, size: targetSize))

            // PDFKit dessine dans un repère origine bas-gauche : on retourne l'axe Y.
            ctx.cgContext.translateBy(x: 0, y: targetSize.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }
}

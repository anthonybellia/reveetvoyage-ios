import SwiftUI
import MapKit
import QuickLook
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

                if let description = etape.description, !description.isEmpty {
                    descriptionCard(description)
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
            .background(Capsule().fill(Color.revBrown.opacity(0.8)))
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

    private func descriptionCard(_ text: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "Notes", systemImage: "note.text")
                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(.revText)
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
        }
    }

    private func imageThumb(_ url: URL) -> some View {
        AsyncImage(url: url) { phase in
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
            default:
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
        ZStack {
            Color.black.opacity(0.92)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        fullScreenImageURL = nil
                    }
                }

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        saveImageToPhotos(from: url)
                    } label: {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.trailing, 8)

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            fullScreenImageURL = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(.horizontal, 12)
                    default:
                        ProgressView().tint(.white)
                    }
                }

                Spacer()
            }
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
            .background(Capsule().fill(Color.revBrown.opacity(0.9)))
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

    private var typeLabel: String {
        switch etape.type {
        case "vol_aller": return "Vol aller"
        case "vol_retour": return "Vol retour"
        case "vol": return "Vol"
        case "hotel": return "Hôtel"
        case "activite": return "Activité"
        case "transfert": return "Transfert"
        case "restaurant": return "Restaurant"
        case "note": return "Note"
        case "document": return "Document"
        default: return etape.type.capitalized
        }
    }

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

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

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

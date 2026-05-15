import SwiftUI
import MapKit

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if etape.hasCoordinates {
                    mapHero
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
            if let lat = etape.latitude, let lng = etape.longitude {
                Button("Apple Plans") { openInApplePlans(lat: lat, lng: lng) }
                Button("Google Maps") { openInGoogleMaps(lat: lat, lng: lng) }
                Button("Annuler", role: .cancel) {}
            }
        }
        .onAppear {
            if let lat = etape.latitude, let lng = etape.longitude {
                region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            }
        }
    }

    // MARK: - Map

    private var mapHero: some View {
        ZStack(alignment: .topLeading) {
            Map(coordinateRegion: $region,
                annotationItems: [Pin(coordinate: CLLocationCoordinate2D(
                    latitude: etape.latitude ?? 0, longitude: etape.longitude ?? 0))]) { p in
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
            if etape.hasCoordinates {
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

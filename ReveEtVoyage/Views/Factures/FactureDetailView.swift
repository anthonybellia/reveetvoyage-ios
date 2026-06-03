import SwiftUI

struct FactureDetailView: View {
    @State private var facture: Facture
    @State private var showEditSheet: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var showStatutPicker: Bool = false
    @State private var showShare: Bool = false
    @State private var pdfDownloadURL: URL? = nil
    @State private var isDownloading: Bool = false
    @Environment(\.dismiss) private var dismiss

    private var isAdmin: Bool {
        AuthService.shared.isAdmin
    }

    init(facture: Facture) {
        _facture = State(initialValue: facture)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroCard
                clientCard
                lignesCard
                totalsCard
                if let n = facture.notes, !n.isEmpty {
                    notesCard(n)
                }
                pdfButton
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .background(
            LinearGradient(colors: [Color.revYellow.opacity(0.06), Color.revBackground],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        )
        .navigationTitle(facture.numero)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isAdmin {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("Modifier", systemImage: "pencil")
                        }
                        Button {
                            showStatutPicker = true
                        } label: {
                            Label("Changer le statut", systemImage: "tag")
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
        .sheet(isPresented: $showEditSheet) {
            FactureFormSheet(mode: .edit(facture)) { updated in
                facture = updated
            }
        }
        .confirmationDialog("Statut de la facture", isPresented: $showStatutPicker, titleVisibility: .visible) {
            Button("Brouillon") { Task { await setStatut("brouillon") } }
            Button("Envoyée") { Task { await setStatut("envoyee") } }
            Button("Payée") { Task { await setStatut("payee") } }
            Button("Annulée", role: .destructive) { Task { await setStatut("annulee") } }
            Button("Annuler", role: .cancel) {}
        }
        .confirmationDialog("Supprimer cette facture ?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                Task {
                    try? await FactureService.shared.deleteFacture(id: facture.id)
                    dismiss()
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("La facture \(facture.numero) sera supprimée définitivement.")
        }
        .sheet(isPresented: $showShare) {
            if let url = pdfDownloadURL {
                ShareSheet(items: [url])
            }
        }
    }

    private var heroCard: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(facture.numero)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.revText)
                        if let date = facture.date_emission {
                            Text("Émise le \(formatDate(date))")
                                .font(.system(size: 12))
                                .foregroundColor(.revTextSecondary)
                        }
                    }
                    Spacer()
                    Text(statutLabel)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(statutColor)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(statutColor.opacity(0.14)))
                }
                Divider()
                HStack {
                    Text("Total TTC")
                        .font(.system(size: 13))
                        .foregroundColor(.revTextSecondary)
                    Spacer()
                    Text(String(format: "€%.2f", facture.total))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.revOrange)
                }
            }
        }
    }

    private var clientCard: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle(title: "Client", systemImage: "person.crop.circle.fill")
                Text(facture.client_nom)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.revText)
                if let email = facture.client_email {
                    Label(email, systemImage: "envelope.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.revTextSecondary)
                }
                if let addr = facture.client_adresse {
                    Text(addr)
                        .font(.system(size: 12))
                        .foregroundColor(.revTextSecondary)
                }
                let city = [facture.client_code_postal, facture.client_ville, facture.client_pays]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                if !city.isEmpty {
                    Text(city)
                        .font(.system(size: 12))
                        .foregroundColor(.revTextSecondary)
                }
            }
        }
    }

    private var lignesCard: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "Détail", systemImage: "list.bullet.rectangle")
                ForEach(facture.lignes) { ligne in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ligne.description)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.revText)
                            if !ligne.reference.isEmpty {
                                Text(ligne.reference)
                                    .font(.system(size: 10))
                                    .foregroundColor(.revTextSecondary)
                            }
                            Text("\(formatQty(ligne.quantite)) × \(String(format: "€%.2f", ligne.prix_unitaire))")
                                .font(.system(size: 11))
                                .foregroundColor(.revTextSecondary)
                        }
                        Spacer()
                        Text(String(format: "€%.2f", ligne.total ?? (ligne.quantite * ligne.prix_unitaire)))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.revText)
                    }
                    Divider()
                }
            }
        }
    }

    private var totalsCard: some View {
        GlassCard(padding: 14) {
            VStack(spacing: 8) {
                row("Sous-total", value: facture.sous_total)
                row("TVA \(formatQty(facture.tva_pct))%", value: facture.tva_montant)
                Divider()
                HStack {
                    Text("Total")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.revText)
                    Spacer()
                    Text(String(format: "€%.2f", facture.total))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.revOrange)
                }
            }
        }
    }

    private func row(_ label: String, value: Double) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.revTextSecondary)
            Spacer()
            Text(String(format: "€%.2f", value))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.revText)
        }
    }

    private func notesCard(_ notes: String) -> some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                SectionTitle(title: "Notes", systemImage: "note.text")
                Text(notes)
                    .font(.system(size: 13))
                    .foregroundColor(.revText)
            }
        }
    }

    private var pdfButton: some View {
        Button {
            Task { await downloadPDF() }
        } label: {
            HStack {
                if isDownloading {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "arrow.down.doc.fill")
                }
                Text(isDownloading ? "Téléchargement…" : "Télécharger le PDF")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(colors: [.revOrange, .revRed], startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(14)
        }
        .disabled(isDownloading)
    }

    private func setStatut(_ statut: String) async {
        do {
            facture = try await FactureService.shared.updateStatut(id: facture.id, statut: statut)
        } catch {
            // ignore
        }
    }

    private func downloadPDF() async {
        guard let url = URL(string: facture.pdf_url) else { return }
        isDownloading = true
        defer { isDownloading = false }
        do {
            var req = URLRequest(url: url)
            if let token = KeychainHelper.shared.getToken() {
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            let (data, _) = try await URLSession.shared.data(for: req)
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("facture-\(facture.numero).pdf")
            try data.write(to: dest)
            pdfDownloadURL = dest
            showShare = true
        } catch {
            // ignore
        }
    }

    private var statutColor: Color {
        switch facture.statut {
        case "payee": return .green
        case "envoyee": return .blue
        case "annulee": return .red
        default: return .revOrange
        }
    }

    private var statutLabel: String {
        switch facture.statut {
        case "payee": return "Payée"
        case "envoyee": return "Envoyée"
        case "annulee": return "Annulée"
        case "brouillon": return "Brouillon"
        default: return facture.statut.capitalized
        }
    }

    private func formatDate(_ str: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        if let d = f.date(from: String(str.prefix(10))) {
            let out = DateFormatter()
            out.locale = Locale(identifier: "fr_FR")
            out.dateFormat = "d MMM yyyy"
            return out.string(from: d)
        }
        return str
    }

    private func formatQty(_ q: Double) -> String {
        if q == q.rounded() { return String(format: "%.0f", q) }
        return String(format: "%.2f", q)
    }
}

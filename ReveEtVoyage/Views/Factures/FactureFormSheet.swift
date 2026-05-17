import SwiftUI

struct FactureFormSheet: View {
    enum Mode {
        case create
        case edit(Facture)
    }

    let mode: Mode
    let onSaved: (Facture) -> Void

    @Environment(\.dismiss) private var dismiss

    // Client
    @State private var customer: ApiCustomer? = nil
    @State private var clientNom: String = ""
    @State private var clientEmail: String = ""
    @State private var clientAdresse: String = ""
    @State private var clientCP: String = ""
    @State private var clientVille: String = ""
    @State private var clientPays: String = "Belgique"
    @State private var communication: String = ""

    // Facture
    @State private var dateEmission: Date = Date()
    @State private var hasEcheance: Bool = true
    @State private var dateEcheance: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var tvaPct: String = "0"
    @State private var statut: String = "brouillon"
    @State private var notes: String = ""
    @State private var lignes: [DraftLigne] = [DraftLigne(description: "", reference: "", quantite: "1", prix_unitaire: "0")]

    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showCustomerPicker: Bool = false

    private struct DraftLigne: Identifiable {
        let id = UUID()
        var description: String
        var reference: String
        var quantite: String
        var prix_unitaire: String
    }

    private let statutOptions: [(value: String, label: String)] = [
        ("brouillon", "Brouillon"),
        ("envoyee", "Envoyée"),
        ("payee", "Payée"),
        ("annulee", "Annulée"),
    ]

    var body: some View {
        NavigationView {
            Form {
                if isCreate {
                    customerPickerSection
                }
                clientSection
                infoSection
                lignesSection
                paramSection
                notesSection

                if let err = errorMessage {
                    Section {
                        Text(err).font(.system(size: 13)).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(isCreate ? "Nouvelle facture" : "Modifier la facture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(.revOrange)
                        } else {
                            Text("Enregistrer").fontWeight(.semibold).foregroundColor(.revOrange)
                        }
                    }
                    .disabled(isSaving || clientNom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: preload)
            .sheet(isPresented: $showCustomerPicker) {
                CustomerPickerView { picked in
                    customer = picked
                    if clientNom.isEmpty { clientNom = picked.name }
                    if clientEmail.isEmpty { clientEmail = picked.email }
                }
            }
        }
    }

    // MARK: - Sections

    private var customerPickerSection: some View {
        Section("Client (compte)") {
            Button {
                showCustomerPicker = true
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundColor(.revOrange)
                    Text(customer?.name ?? "Sélectionner…")
                        .foregroundColor(customer == nil ? .revTextSecondary : .revText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.revTextSecondary)
                        .font(.system(size: 12))
                }
            }
        }
    }

    private var clientSection: some View {
        Section("Coordonnées client") {
            TextField("Nom complet *", text: $clientNom).autocapitalization(.words)
            TextField("Email", text: $clientEmail).keyboardType(.emailAddress).autocapitalization(.none)
            TextField("Adresse", text: $clientAdresse)
            HStack {
                TextField("CP", text: $clientCP).frame(maxWidth: 90)
                TextField("Ville", text: $clientVille)
            }
            TextField("Pays", text: $clientPays)
            TextField("Communication", text: $communication)
        }
    }

    private var infoSection: some View {
        Section("Dates") {
            DatePicker("Émission", selection: $dateEmission, displayedComponents: [.date])
            Toggle("Date d'échéance", isOn: $hasEcheance)
            if hasEcheance {
                DatePicker("Échéance", selection: $dateEcheance, displayedComponents: [.date])
            }
        }
    }

    private var lignesSection: some View {
        Section("Lignes") {
            ForEach($lignes) { $ligne in
                VStack(spacing: 6) {
                    TextField("Description", text: $ligne.description)
                    HStack {
                        TextField("Qté", text: $ligne.quantite)
                            .keyboardType(.decimalPad)
                            .frame(maxWidth: 60)
                        TextField("Prix unitaire", text: $ligne.prix_unitaire)
                            .keyboardType(.decimalPad)
                        Text("€").foregroundColor(.revTextSecondary)
                    }
                    TextField("Référence (optionnel)", text: $ligne.reference)
                        .font(.system(size: 12))
                        .foregroundColor(.revTextSecondary)
                }
            }
            .onDelete { idx in
                lignes.remove(atOffsets: idx)
                if lignes.isEmpty {
                    lignes.append(DraftLigne(description: "", reference: "", quantite: "1", prix_unitaire: "0"))
                }
            }

            Button {
                lignes.append(DraftLigne(description: "", reference: "", quantite: "1", prix_unitaire: "0"))
            } label: {
                Label("Ajouter une ligne", systemImage: "plus.circle")
                    .foregroundColor(.revOrange)
            }

            HStack {
                Text("Total HT calculé")
                    .font(.system(size: 13))
                    .foregroundColor(.revTextSecondary)
                Spacer()
                Text(String(format: "€%.2f", computedSousTotal))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.revText)
            }
        }
    }

    private var paramSection: some View {
        Section("Paramètres") {
            HStack {
                Text("TVA")
                Spacer()
                TextField("0", text: $tvaPct)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 80)
                Text("%").foregroundColor(.revTextSecondary)
            }
            Picker("Statut", selection: $statut) {
                ForEach(statutOptions, id: \.value) { Text($0.label).tag($0.value) }
            }
            .pickerStyle(.menu)
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextEditor(text: $notes).frame(minHeight: 60)
        }
    }

    // MARK: - Logic

    private var isCreate: Bool { if case .create = mode { return true } else { return false } }

    private var computedSousTotal: Double {
        lignes.reduce(0.0) { acc, l in
            let q = Double(l.quantite.replacingOccurrences(of: ",", with: ".")) ?? 0
            let p = Double(l.prix_unitaire.replacingOccurrences(of: ",", with: ".")) ?? 0
            return acc + q * p
        }
    }

    private func preload() {
        guard case .edit(let f) = mode else { return }
        clientNom = f.client_nom
        clientEmail = f.client_email ?? ""
        clientAdresse = f.client_adresse ?? ""
        clientCP = f.client_code_postal ?? ""
        clientVille = f.client_ville ?? ""
        clientPays = f.client_pays ?? "Belgique"
        communication = f.communication ?? ""
        tvaPct = String(format: "%g", f.tva_pct)
        statut = f.statut
        notes = f.notes ?? ""
        if let d = f.date_emission, let parsed = parseDate(d) { dateEmission = parsed }
        if let d = f.date_echeance, let parsed = parseDate(d) {
            hasEcheance = true
            dateEcheance = parsed
        } else {
            hasEcheance = false
        }
        lignes = f.lignes.isEmpty
            ? [DraftLigne(description: "", reference: "", quantite: "1", prix_unitaire: "0")]
            : f.lignes.map {
                DraftLigne(
                    description: $0.description,
                    reference: $0.reference,
                    quantite: String(format: "%g", $0.quantite),
                    prix_unitaire: String(format: "%g", $0.prix_unitaire)
                )
            }
    }

    private func save() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        let payloadLignes: [FactureLignePayload] = lignes.map { l in
            FactureLignePayload(
                description: l.description,
                reference: l.reference.isEmpty ? nil : l.reference,
                quantite: Double(l.quantite.replacingOccurrences(of: ",", with: ".")) ?? 0,
                prix_unitaire: Double(l.prix_unitaire.replacingOccurrences(of: ",", with: ".")) ?? 0
            )
        }

        let payload = FacturePayload(
            devis_id: nil,
            voyage_id: nil,
            user_id: customer?.id,
            client_nom: clientNom.trimmingCharacters(in: .whitespacesAndNewlines),
            client_email: clientEmail.isEmpty ? nil : clientEmail,
            client_adresse: clientAdresse.isEmpty ? nil : clientAdresse,
            client_ville: clientVille.isEmpty ? nil : clientVille,
            client_code_postal: clientCP.isEmpty ? nil : clientCP,
            client_pays: clientPays.isEmpty ? nil : clientPays,
            communication: communication.isEmpty ? nil : communication,
            lignes: payloadLignes,
            tva_pct: Double(tvaPct.replacingOccurrences(of: ",", with: ".")) ?? 0,
            statut: statut,
            notes: notes.isEmpty ? nil : notes,
            date_emission: Self.fmt.string(from: dateEmission),
            date_echeance: hasEcheance ? Self.fmt.string(from: dateEcheance) : nil
        )

        do {
            let saved: Facture
            switch mode {
            case .create:
                saved = try await FactureService.shared.createFacture(payload: payload)
            case .edit(let f):
                saved = try await FactureService.shared.updateFacture(id: f.id, payload: payload)
            }
            onSaved(saved)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func parseDate(_ str: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: String(str.prefix(10)))
    }

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

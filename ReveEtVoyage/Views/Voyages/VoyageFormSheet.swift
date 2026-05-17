import SwiftUI

/// Admin-only form to create or edit a voyage.
struct VoyageFormSheet: View {
    enum Mode {
        case create
        case edit(Voyage)
    }

    let mode: Mode
    let onSaved: (Voyage) -> Void

    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var customer: ApiCustomer? = nil
    @State private var titre: String = ""
    @State private var destination: String = ""
    @State private var hasDepart: Bool = false
    @State private var dateDepart: Date = Date()
    @State private var hasRetour: Bool = false
    @State private var dateRetour: Date = Date()
    @State private var montantTotal: String = ""
    @State private var acompteType: String = "pct"
    @State private var acompteValeur: String = "30"
    @State private var statut: String = "en_preparation"
    @State private var description: String = ""
    @State private var notesAdmin: String = ""

    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showCustomerPicker: Bool = false

    private let statutOptions: [(value: String, label: String)] = [
        ("en_preparation", "En préparation"),
        ("confirme", "Confirmé"),
        ("en_cours", "En cours"),
        ("termine", "Terminé"),
        ("annule", "Annulé"),
    ]

    var body: some View {
        NavigationView {
            Form {
                customerSection
                identitySection
                datesSection
                financialSection
                statutSection
                notesSection

                if let err = errorMessage {
                    Section {
                        Text(err).font(.system(size: 13)).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(isCreate ? "Nouveau voyage" : "Modifier le voyage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundColor(.revTextSecondary)
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
                    .disabled(isSaving || !canSave)
                }
            }
            .onAppear(perform: preload)
            .sheet(isPresented: $showCustomerPicker) {
                CustomerPickerView { picked in
                    customer = picked
                }
            }
        }
    }

    // MARK: - Sections

    private var customerSection: some View {
        Section("Client") {
            Button {
                showCustomerPicker = true
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundColor(.revOrange)
                    VStack(alignment: .leading, spacing: 2) {
                        if let c = customer {
                            Text(c.name)
                                .foregroundColor(.revText)
                                .font(.system(size: 15, weight: .medium))
                            Text(c.email)
                                .font(.system(size: 11))
                                .foregroundColor(.revTextSecondary)
                        } else {
                            Text("Sélectionner un client…")
                                .foregroundColor(.revTextSecondary)
                                .font(.system(size: 15))
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.revTextSecondary)
                        .font(.system(size: 12))
                }
            }
        }
    }

    private var identitySection: some View {
        Section("Identité") {
            TextField("Titre du voyage *", text: $titre)
                .autocapitalization(.sentences)
            TextField("Destination", text: $destination)
                .autocapitalization(.sentences)
        }
    }

    private var datesSection: some View {
        Section("Dates") {
            Toggle("Départ", isOn: $hasDepart)
            if hasDepart {
                DatePicker("", selection: $dateDepart, displayedComponents: [.date])
                    .labelsHidden()
            }
            Toggle("Retour", isOn: $hasRetour)
            if hasRetour {
                DatePicker("", selection: $dateRetour, displayedComponents: [.date])
                    .labelsHidden()
            }
        }
    }

    private var financialSection: some View {
        Section("Tarif") {
            HStack {
                Text("Montant total")
                Spacer()
                TextField("0", text: $montantTotal)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                Text("€").foregroundColor(.revTextSecondary)
            }
            Picker("Type d'acompte", selection: $acompteType) {
                Text("Pourcentage").tag("pct")
                Text("Montant fixe").tag("montant")
            }
            HStack {
                Text("Valeur acompte")
                Spacer()
                TextField("0", text: $acompteValeur)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                Text(acompteType == "pct" ? "%" : "€")
                    .foregroundColor(.revTextSecondary)
            }
        }
    }

    private var statutSection: some View {
        Section("Statut") {
            Picker("Statut", selection: $statut) {
                ForEach(statutOptions, id: \.value) { opt in
                    Text(opt.label).tag(opt.value)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var notesSection: some View {
        Section("Description & notes") {
            TextEditor(text: $description)
                .frame(minHeight: 80)
                .font(.system(size: 14))
                .overlay(alignment: .topLeading) {
                    if description.isEmpty {
                        Text("Description visible par le client…")
                            .font(.system(size: 14))
                            .foregroundColor(.revTextSecondary.opacity(0.55))
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                }
            TextEditor(text: $notesAdmin)
                .frame(minHeight: 60)
                .font(.system(size: 14))
                .overlay(alignment: .topLeading) {
                    if notesAdmin.isEmpty {
                        Text("Notes internes (admin)…")
                            .font(.system(size: 14))
                            .foregroundColor(.revTextSecondary.opacity(0.55))
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: - Logic

    private var isCreate: Bool {
        if case .create = mode { return true }
        return false
    }

    private var canSave: Bool {
        customer != nil
            && !titre.trimmingCharacters(in: .whitespaces).isEmpty
            && Double(montantTotal.replacingOccurrences(of: ",", with: ".")) != nil
    }

    private func preload() {
        guard case .edit(let voyage) = mode else { return }
        titre = voyage.titre
        destination = voyage.destination
        montantTotal = String(format: "%g", voyage.montant_total)
        acompteType = voyage.acompte_type
        acompteValeur = String(format: "%g", voyage.acompte_valeur)
        statut = voyage.statut
        description = voyage.description ?? ""

        if let d = voyage.date_depart, let parsed = parseISODate(d) {
            hasDepart = true
            dateDepart = parsed
        }
        if let d = voyage.date_retour, let parsed = parseISODate(d) {
            hasRetour = true
            dateRetour = parsed
        }

        if let owner = voyage.owner {
            customer = ApiCustomer(id: owner.id, name: owner.fullName, email: owner.email ?? "")
        }
    }

    private func save() async {
        errorMessage = nil
        guard let customer = customer else { return }
        guard let total = Double(montantTotal.replacingOccurrences(of: ",", with: ".")) else { return }
        let acompte = Double(acompteValeur.replacingOccurrences(of: ",", with: ".")) ?? 0

        isSaving = true
        defer { isSaving = false }

        let payload = VoyagePayload(
            user_id: customer.id,
            titre: titre.trimmingCharacters(in: .whitespacesAndNewlines),
            destination: destination.isEmpty ? nil : destination,
            date_depart: hasDepart ? Self.dateFormatter.string(from: dateDepart) : nil,
            date_retour: hasRetour ? Self.dateFormatter.string(from: dateRetour) : nil,
            montant_total: total,
            acompte_type: acompteType,
            acompte_valeur: acompte,
            statut: statut,
            description: description.isEmpty ? nil : description,
            notes_admin: notesAdmin.isEmpty ? nil : notesAdmin
        )

        do {
            let voyage: Voyage
            switch mode {
            case .create:
                voyage = try await VoyageService.shared.createVoyage(payload: payload)
            case .edit(let existing):
                voyage = try await VoyageService.shared.updateVoyage(id: existing.id, payload: payload)
            }
            onSaved(voyage)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func parseISODate(_ str: String) -> Date? {
        let isoFull = ISO8601DateFormatter()
        if let d = isoFull.date(from: str) { return d }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: String(str.prefix(10)))
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

// MARK: - Customer picker

struct CustomerPickerView: View {
    let onSelect: (ApiCustomer) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var results: [ApiCustomer] = []
    @State private var isLoading: Bool = false
    @State private var searchTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.revTextSecondary)
                    TextField("Nom, email…", text: $query)
                        .autocorrectionDisabled()
                        .onChange(of: query) { newValue in
                            debounceSearch(newValue)
                        }
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.revTextSecondary)
                        }
                    }
                }
                .padding(12)
                .background(Color.revCardBackground)

                Divider()

                if isLoading && results.isEmpty {
                    ProgressView().tint(.revOrange).padding(.top, 40)
                    Spacer()
                } else if results.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 36))
                            .foregroundColor(.revOrange.opacity(0.4))
                        Text(query.isEmpty ? "Tape pour rechercher un client" : "Aucun client trouvé")
                            .foregroundColor(.revTextSecondary)
                    }
                    .padding(.top, 60)
                    Spacer()
                } else {
                    List(results) { customer in
                        Button {
                            onSelect(customer)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(customer.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.revText)
                                Text(customer.email)
                                    .font(.system(size: 12))
                                    .foregroundColor(.revTextSecondary)
                            }
                        }
                        .listRowBackground(Color.revCardBackground)
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.revBackground.ignoresSafeArea())
            .navigationTitle("Choisir un client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundColor(.revOrange)
                }
            }
            .task {
                await runSearch(nil)
            }
        }
    }

    private func debounceSearch(_ value: String) {
        searchTask?.cancel()
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 280_000_000)
            if Task.isCancelled { return }
            await runSearch(trimmed.isEmpty ? nil : trimmed)
        }
    }

    private func runSearch(_ q: String?) async {
        isLoading = true
        do {
            let res = try await CustomerService.shared.listCustomers(query: q)
            if !Task.isCancelled { results = res }
        } catch {
            results = []
        }
        isLoading = false
    }
}

import SwiftUI

/// Admin-only form to edit a devis (workflow fields + raw request fields).
struct DevisFormSheet: View {
    let devis: Devis
    let onSaved: (Devis) -> Void

    @Environment(\.dismiss) private var dismiss

    // Workflow
    @State private var statut: String = "nouveau"
    @State private var titreVoyage: String = ""
    @State private var montantEstime: String = ""
    @State private var hasDepartPrevue: Bool = false
    @State private var dateDepartPrevue: Date = Date()
    @State private var hasRetourPrevue: Bool = false
    @State private var dateRetourPrevue: Date = Date()
    @State private var notesAdmin: String = ""

    // Raw request fields
    @State private var destination: String = ""
    @State private var datesSouhaitees: String = ""
    @State private var duree: String = ""
    @State private var nbPersonnes: String = ""
    @State private var participants: String = ""
    @State private var budget: String = ""
    @State private var typeVoyage: String = ""
    @State private var message: String = ""

    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    private let statutOptions: [(value: String, label: String)] = [
        ("nouveau", "Nouveau"),
        ("en_cours", "En cours"),
        ("traite", "Traité"),
        ("annule", "Annulé"),
    ]

    private let typeOptions: [(value: String, label: String)] = [
        ("", "—"),
        ("couple", "Couple"),
        ("famille", "Famille"),
        ("amis", "Amis"),
        ("solo", "Solo"),
        ("lune_de_miel", "Lune de miel"),
    ]

    var body: some View {
        NavigationView {
            Form {
                workflowSection
                proposedTripSection
                rawRequestSection
                adminNotesSection

                if let err = errorMessage {
                    Section {
                        Text(err).font(.system(size: 13)).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Modifier la demande")
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
                    .disabled(isSaving)
                }
            }
            .onAppear(perform: preload)
        }
    }

    // MARK: - Sections

    private var workflowSection: some View {
        Section("Statut") {
            Picker("Statut", selection: $statut) {
                ForEach(statutOptions, id: \.value) { opt in
                    Text(opt.label).tag(opt.value)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var proposedTripSection: some View {
        Section("Voyage proposé") {
            TextField("Titre du voyage", text: $titreVoyage)
                .autocapitalization(.sentences)

            HStack {
                Text("Montant estimé")
                Spacer()
                TextField("0", text: $montantEstime)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                Text("€").foregroundColor(.revTextSecondary)
            }

            Toggle("Date départ prévue", isOn: $hasDepartPrevue)
            if hasDepartPrevue {
                DatePicker("", selection: $dateDepartPrevue, displayedComponents: [.date])
                    .labelsHidden()
            }
            Toggle("Date retour prévue", isOn: $hasRetourPrevue)
            if hasRetourPrevue {
                DatePicker("", selection: $dateRetourPrevue, displayedComponents: [.date])
                    .labelsHidden()
            }
        }
    }

    private var rawRequestSection: some View {
        Section("Demande du client (modifier)") {
            TextField("Destination", text: $destination)
            TextField("Dates souhaitées", text: $datesSouhaitees)
            TextField("Durée", text: $duree)
            HStack {
                Text("Nb. personnes")
                Spacer()
                TextField("0", text: $nbPersonnes)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
            }
            TextField("Participants", text: $participants)
            TextField("Budget", text: $budget)
            Picker("Type", selection: $typeVoyage) {
                ForEach(typeOptions, id: \.value) { opt in
                    Text(opt.label).tag(opt.value)
                }
            }
            .pickerStyle(.menu)
            TextField("Message", text: $message, axis: .vertical)
                .lineLimit(2...5)
        }
    }

    private var adminNotesSection: some View {
        Section("Notes internes (admin)") {
            TextEditor(text: $notesAdmin)
                .frame(minHeight: 80)
                .font(.system(size: 14))
        }
    }

    // MARK: - Logic

    private func preload() {
        statut = devis.statut
        titreVoyage = devis.titre_voyage ?? ""
        montantEstime = devis.montant_estime ?? ""
        destination = devis.destination ?? ""
        datesSouhaitees = devis.dates_souhaitees ?? ""
        duree = devis.duree ?? ""
        if let n = devis.nb_personnes { nbPersonnes = String(n) }
        participants = devis.participants ?? ""
        budget = devis.budget ?? ""
        typeVoyage = devis.type_voyage ?? ""
        message = devis.message ?? ""

        if let d = devis.date_depart_prevue, let parsed = parseISODate(d) {
            hasDepartPrevue = true
            dateDepartPrevue = parsed
        }
        if let d = devis.date_retour_prevue, let parsed = parseISODate(d) {
            hasRetourPrevue = true
            dateRetourPrevue = parsed
        }
    }

    private func save() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        let payload = DevisAdminPayload(
            destination: destination.isEmpty ? nil : destination,
            destination_souhaitee: nil,
            dates_souhaitees: datesSouhaitees.isEmpty ? nil : datesSouhaitees,
            duree: duree.isEmpty ? nil : duree,
            nb_personnes: Int(nbPersonnes),
            participants: participants.isEmpty ? nil : participants,
            budget: budget.isEmpty ? nil : budget,
            type_voyage: typeVoyage.isEmpty ? nil : typeVoyage,
            message: message.isEmpty ? nil : message,
            statut: statut,
            notes_admin: notesAdmin.isEmpty ? nil : notesAdmin,
            titre_voyage: titreVoyage.isEmpty ? nil : titreVoyage,
            montant_estime: Double(montantEstime.replacingOccurrences(of: ",", with: ".")),
            date_depart_prevue: hasDepartPrevue ? Self.dateFormatter.string(from: dateDepartPrevue) : nil,
            date_retour_prevue: hasRetourPrevue ? Self.dateFormatter.string(from: dateRetourPrevue) : nil
        )

        do {
            let updated = try await DevisService.shared.updateDevis(id: devis.id, payload: payload)
            onSaved(updated)
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

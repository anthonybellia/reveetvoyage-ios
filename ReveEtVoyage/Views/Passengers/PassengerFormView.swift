import SwiftUI

struct PassengerFormView: View {
    let passenger: Passenger?
    let onSave: (PassengerCreateRequest) async -> Bool

    @Environment(\.dismiss) private var dismiss

    @State private var prenom: String = ""
    @State private var nom: String = ""
    @State private var dateNaissance: Date = Date()
    @State private var hasDateNaissance: Bool = false
    @State private var nationalite: String = ""
    @State private var typeDoc: DocType = .none
    @State private var numDoc: String = ""
    @State private var expirationDoc: Date = Date()
    @State private var hasExpirationDoc: Bool = false
    @State private var isDefault: Bool = false
    @State private var notes: String = ""
    @State private var isSaving: Bool = false

    enum DocType: String, CaseIterable, Identifiable {
        case none = ""
        case carteIdentite = "carte_identite"
        case passeport = "passeport"

        var id: Self { self }
        var label: String {
            switch self {
            case .none: return "Aucun"
            case .carteIdentite: return "Carte d'identité"
            case .passeport: return "Passeport"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identité") {
                    TextField("Prénom", text: $prenom)
                    TextField("Nom", text: $nom)
                    Toggle("Date de naissance", isOn: $hasDateNaissance.animation())
                    if hasDateNaissance {
                        DatePicker("Né(e) le", selection: $dateNaissance, displayedComponents: .date)
                    }
                    TextField("Nationalité", text: $nationalite)
                }

                Section("Document de voyage") {
                    Picker("Type de document", selection: $typeDoc) {
                        ForEach(DocType.allCases) { Text($0.label).tag($0) }
                    }
                    if typeDoc != .none {
                        TextField("Numéro", text: $numDoc)
                            .autocapitalization(.allCharacters)
                        Toggle("Date d'expiration", isOn: $hasExpirationDoc.animation())
                        if hasExpirationDoc {
                            DatePicker("Expire le", selection: $expirationDoc, displayedComponents: .date)
                        }
                    }
                }

                Section("Préférences") {
                    Toggle("Passager principal", isOn: $isDefault)
                        .tint(.revOrange)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(colors: [Color.revYellow.opacity(0.06), Color.revBackground],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .navigationTitle(passenger == nil ? "Nouveau passager" : "Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(.revOrange)
                        } else {
                            Text("Enregistrer").bold()
                        }
                    }
                    .disabled(prenom.isEmpty || nom.isEmpty || isSaving)
                }
            }
            .onAppear { hydrateForm() }
        }
    }

    private func hydrateForm() {
        guard let p = passenger else { return }
        prenom = p.prenom
        nom = p.nom
        nationalite = p.nationalite ?? ""
        if let d = p.date_naissance?.toDate() {
            dateNaissance = d
            hasDateNaissance = true
        }
        if let typ = p.type_doc, let dt = DocType(rawValue: typ) {
            typeDoc = dt
        }
        numDoc = p.num_doc ?? ""
        if let d = p.expiration_doc?.toDate() {
            expirationDoc = d
            hasExpirationDoc = true
        }
        isDefault = p.is_default
        notes = p.notes ?? ""
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "en_US_POSIX")
        dateFmt.dateFormat = "yyyy-MM-dd"

        let req = PassengerCreateRequest(
            nom: nom,
            prenom: prenom,
            date_naissance: hasDateNaissance ? dateFmt.string(from: dateNaissance) : nil,
            type_doc: typeDoc == .none ? nil : typeDoc.rawValue,
            num_doc: numDoc.isEmpty ? nil : numDoc,
            nationalite: nationalite.isEmpty ? nil : nationalite,
            langues: [],
            notes: notes.isEmpty ? nil : notes,
            expiration_doc: hasExpirationDoc ? dateFmt.string(from: expirationDoc) : nil,
            is_default: isDefault
        )

        if await onSave(req) {
            dismiss()
        }
    }
}

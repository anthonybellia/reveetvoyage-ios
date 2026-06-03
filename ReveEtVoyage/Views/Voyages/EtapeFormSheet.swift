import SwiftUI

/// Admin-only form to create or edit a voyage étape.
/// Reuses PlaceAutocompleteView for lieu/coordinates picking.
struct EtapeFormSheet: View {
    enum Mode {
        case create(voyageId: Int)
        case edit(voyageId: Int, etape: VoyageEtape)
    }

    let mode: Mode
    let onSaved: (VoyageEtape) -> Void

    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var type: String = "activite"
    @State private var titre: String = ""
    @State private var hasDate: Bool = false
    @State private var date: Date = Date()
    @State private var hasHeure: Bool = false
    @State private var heure: Date = Date()
    @State private var lieu: String = ""
    @State private var adresse: String = ""
    @State private var latitude: Double? = nil
    @State private var longitude: Double? = nil
    @State private var description: String = ""
    /// HTML riche original (provenant de l'éditeur web), conservé tel quel pour
    /// éviter de l'écraser si l'admin n'a pas réellement modifié le contenu.
    @State private var originalContenuHtml: String? = nil

    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showPlacePicker: Bool = false

    /// Liste complète des types d'étape, alignée sur l'admin web et les valeurs
    /// `type` stockées en base (chaînes exactes utilisées par le backend).
    private let etapeTypes: [(value: String, label: String, icon: String)] = [
        ("vol_aller", "Vol aller", "airplane.departure"),
        ("vol_retour", "Vol retour", "airplane.arrival"),
        ("train", "Train", "tram.fill"),
        ("hotel", "Hôtel", "bed.double.fill"),
        ("activite", "Activité", "figure.walk"),
        ("restaurant", "Restaurant", "fork.knife"),
        ("brunch", "Brunch", "sun.max.fill"),
        ("petit_dej", "Petit-déjeuner", "cup.and.saucer.fill"),
        ("cafe", "Café", "cup.and.saucer.fill"),
        ("bar", "Bar", "wineglass.fill"),
        ("transfert", "Transfert", "car.fill"),
        ("visite", "Visite / Musée", "building.columns.fill"),
        ("monument", "Monument", "building.columns.fill"),
        ("croisiere", "Croisière", "ferry.fill"),
        ("note", "Note", "note.text"),
        ("spa", "Spa", "sparkles"),
        ("shopping", "Shopping", "bag.fill"),
        ("plage", "Plage", "beach.umbrella.fill"),
        ("sport", "Sport", "figure.run"),
        ("spectacle", "Spectacle", "theatermasks.fill"),
        ("document", "Document", "doc.fill"),
    ]

    var body: some View {
        NavigationView {
            Form {
                typeSection
                titreSection
                dateHeureSection
                lieuSection
                descriptionSection

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(isCreate ? "Nouvelle étape" : "Modifier l'étape")
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
                    .disabled(isSaving || titre.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: preload)
            .sheet(isPresented: $showPlacePicker) {
                PlaceAutocompleteView(
                    centerLatitude: latitude,
                    centerLongitude: longitude
                ) { place in
                    lieu = place.name
                    adresse = place.address
                    latitude = place.latitude
                    longitude = place.longitude
                    if titre.trimmingCharacters(in: .whitespaces).isEmpty {
                        titre = place.name
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var typeSection: some View {
        Section("Type") {
            Picker("Type d'étape", selection: $type) {
                ForEach(etapeTypes, id: \.value) { t in
                    Label(t.label, systemImage: t.icon).tag(t.value)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var titreSection: some View {
        Section("Titre") {
            TextField("Musée des Offices, Vol BRU → FCO...", text: $titre)
                .autocapitalization(.sentences)
        }
    }

    private var dateHeureSection: some View {
        Section("Date & heure") {
            Toggle("Date", isOn: $hasDate)
            if hasDate {
                DatePicker("", selection: $date, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
            Toggle("Heure", isOn: $hasHeure)
            if hasHeure {
                DatePicker("", selection: $heure, displayedComponents: [.hourAndMinute])
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
        }
    }

    private var lieuSection: some View {
        Section("Lieu") {
            Button {
                showPlacePicker = true
            } label: {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.revOrange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lieu.isEmpty ? "Rechercher un lieu…" : lieu)
                            .foregroundColor(lieu.isEmpty ? .revTextSecondary : .revText)
                            .font(.system(size: 15))
                        if !adresse.isEmpty {
                            Text(adresse)
                                .font(.system(size: 11))
                                .foregroundColor(.revTextSecondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.revTextSecondary)
                        .font(.system(size: 12))
                }
            }
            if !lieu.isEmpty || !adresse.isEmpty {
                Button(role: .destructive) {
                    lieu = ""
                    adresse = ""
                    latitude = nil
                    longitude = nil
                } label: {
                    Label("Effacer le lieu", systemImage: "xmark.circle")
                        .font(.system(size: 13))
                }
            }
        }
    }

    private var descriptionSection: some View {
        Section("Description") {
            TextEditor(text: $description)
                .frame(minHeight: 100)
                .font(.system(size: 14))
        }
    }

    // MARK: - Logic

    private var isCreate: Bool {
        if case .create = mode { return true }
        return false
    }

    private var voyageId: Int {
        switch mode {
        case .create(let id): return id
        case .edit(let id, _): return id
        }
    }

    private func preload() {
        guard case .edit(_, let etape) = mode else { return }
        type = etape.type
        titre = etape.titre
        lieu = etape.lieu ?? ""
        adresse = etape.adresse ?? ""
        latitude = etape.latitude
        longitude = etape.longitude

        // On conserve le HTML riche original intact pour pouvoir le réémettre
        // sans perte si l'admin ne touche pas au contenu.
        originalContenuHtml = etape.contenu_html
        // L'éditeur affiche une version texte brut lisible (jamais de balises HTML).
        if let html = etape.contenu_html, !html.isEmpty {
            description = htmlToPlainText(html)
        } else {
            description = etape.description ?? ""
        }

        if let d = etape.date, let parsed = parseISODate(d) {
            hasDate = true
            date = parsed
        }
        if let h = etape.heure, let parsed = parseTime(h) {
            hasHeure = true
            heure = parsed
        }
    }

    private func save() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        // Détection de modification : on compare le texte brut affiché à l'admin
        // avec la version texte brut du HTML riche original. S'ils correspondent,
        // l'admin n'a rien changé → on réémet le HTML riche d'origine pour ne
        // perdre ni mise en forme ni balises de l'éditeur web.
        let editedText = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let contenuHtml: String?
        let descriptionPlain: String?

        if editedText.isEmpty {
            // Contenu vidé : on n'envoie rien.
            contenuHtml = nil
            descriptionPlain = nil
        } else if let original = originalContenuHtml,
                  htmlToPlainText(original).trimmingCharacters(in: .whitespacesAndNewlines) == editedText {
            // Inchangé → on préserve le HTML riche d'origine.
            contenuHtml = original
            descriptionPlain = nil
        } else {
            // Modifié → on stocke le texte brut, sauts de ligne convertis en <br>
            // pour conserver les retours à la ligne au rendu HTML. On renseigne
            // aussi `description` pour garder les deux champs cohérents.
            contenuHtml = editedText.replacingOccurrences(of: "\n", with: "<br>")
            descriptionPlain = editedText
        }

        let payload = EtapePayload(
            type: type,
            titre: titre.trimmingCharacters(in: .whitespacesAndNewlines),
            date: hasDate ? Self.dateFormatter.string(from: date) : nil,
            heure: hasHeure ? Self.timeFormatter.string(from: heure) : nil,
            lieu: lieu.isEmpty ? nil : lieu,
            adresse: adresse.isEmpty ? nil : adresse,
            latitude: latitude,
            longitude: longitude,
            contenu_html: contenuHtml,
            description: descriptionPlain
        )

        do {
            let etape: VoyageEtape
            switch mode {
            case .create(let id):
                etape = try await VoyageService.shared.createEtape(voyageId: id, payload: payload)
            case .edit(let id, let existing):
                etape = try await VoyageService.shared.updateEtape(voyageId: id, etapeId: existing.id, payload: payload)
            }
            onSaved(etape)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Convertit le HTML riche de l'éditeur web (RVTE) en texte brut lisible.
    /// Les balises de bloc/saut deviennent des retours à la ligne, les autres
    /// balises sont supprimées, et les entités HTML courantes sont décodées.
    private func htmlToPlainText(_ html: String?) -> String {
        guard let html = html, !html.isEmpty else { return "" }
        var s = html

        // 1) Balises de bloc / saut de ligne → newline.
        let newlineTagPatterns = [
            "<br\\s*/?>",
            "<hr[^>]*>",
            "</div>",
            "</p>",
            "</li>",
        ]
        for pattern in newlineTagPatterns {
            s = s.replacingOccurrences(
                of: pattern,
                with: "\n",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        // 2) Suppression de toutes les autres balises restantes.
        s = s.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )

        // 3) Décodage des entités HTML courantes.
        let entities: [(String, String)] = [
            ("&nbsp;", " "),
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&#39;", "'"),
            ("&apos;", "'"),
            ("&quot;", "\""),
        ]
        for (entity, replacement) in entities {
            s = s.replacingOccurrences(of: entity, with: replacement, options: .caseInsensitive)
        }

        // 4) Normalisation : 3+ sauts de ligne consécutifs → 2, puis trim.
        s = s.replacingOccurrences(
            of: "\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseISODate(_ str: String) -> Date? {
        let isoFull = ISO8601DateFormatter()
        if let d = isoFull.date(from: str) { return d }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: String(str.prefix(10)))
    }

    private func parseTime(_ str: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        if let d = f.date(from: String(str.prefix(5))) { return d }
        f.dateFormat = "HH:mm:ss"
        return f.date(from: str)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}


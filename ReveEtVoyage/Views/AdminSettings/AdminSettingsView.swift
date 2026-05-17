import SwiftUI

/// Generic key/value editor for the `settings` table.
/// Groups well-known keys into branded sections; anything unknown falls into "Autres".
struct AdminSettingsView: View {
    @State private var raw: [String: String] = [:]
    @State private var dirty: Bool = false
    @State private var isLoading: Bool = false
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil

    // Grouped sections (key, label, multiline)
    private struct Field { let key: String; let label: String; let multiline: Bool }
    private let groups: [(title: String, icon: String, fields: [Field])] = [
        ("Marque", "paintpalette.fill", [
            Field(key: "site_name", label: "Nom du site", multiline: false),
            Field(key: "site_tagline", label: "Tagline", multiline: false),
            Field(key: "site_phone", label: "Téléphone", multiline: false),
            Field(key: "site_email", label: "Email contact", multiline: false),
            Field(key: "site_address", label: "Adresse postale", multiline: true),
        ]),
        ("Paiements", "creditcard.fill", [
            Field(key: "depot_pct", label: "Pourcentage acompte", multiline: false),
            Field(key: "depot_min", label: "Acompte minimum (€)", multiline: false),
            Field(key: "mollie_api_key", label: "Mollie API key", multiline: false),
        ]),
        ("Réseaux sociaux", "network", [
            Field(key: "social_facebook", label: "Facebook", multiline: false),
            Field(key: "social_instagram", label: "Instagram", multiline: false),
            Field(key: "social_tiktok", label: "TikTok", multiline: false),
            Field(key: "social_youtube", label: "YouTube", multiline: false),
            Field(key: "social_linkedin", label: "LinkedIn", multiline: false),
        ]),
        ("SEO / Tracking", "chart.bar.fill", [
            Field(key: "ga_id", label: "Google Analytics ID", multiline: false),
            Field(key: "ga_measurement_id", label: "GA Measurement ID", multiline: false),
            Field(key: "meta_default_description", label: "Meta description par défaut", multiline: true),
        ]),
    ]

    var body: some View {
        Form {
            if isLoading {
                Section { ProgressView() }
            }
            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                Section {
                    ForEach(group.fields, id: \.key) { field in
                        rowFor(field)
                    }
                } header: {
                    Label(group.title, systemImage: group.icon)
                }
            }

            // "Autres" - keys not in known groups
            let knownKeys = Set(groups.flatMap { $0.fields.map(\.key) })
            let otherKeys = raw.keys.filter { !knownKeys.contains($0) }.sorted()
            if !otherKeys.isEmpty {
                Section("Autres clés") {
                    ForEach(otherKeys, id: \.self) { key in
                        rowFor(Field(key: key, label: key, multiline: false))
                    }
                }
            }

            if let err = errorMessage {
                Section { Text(err).foregroundColor(.red).font(.system(size: 13)) }
            }
            if let ok = successMessage {
                Section { Text(ok).foregroundColor(.green).font(.system(size: 13)) }
            }
        }
        .navigationTitle("Paramètres")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving { ProgressView().tint(.revOrange) }
                    else {
                        Text("Enregistrer")
                            .fontWeight(.semibold)
                            .foregroundColor(dirty ? .revOrange : .revTextSecondary)
                    }
                }
                .disabled(!dirty || isSaving)
            }
        }
        .task { await load() }
    }

    private func rowFor(_ field: Field) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(field.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.revTextSecondary)
            if field.multiline {
                TextEditor(text: binding(for: field.key))
                    .frame(minHeight: 60)
                    .font(.system(size: 13))
            } else {
                TextField(field.label, text: binding(for: field.key))
                    .font(.system(size: 14))
                    .autocapitalization(.none)
            }
        }
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { raw[key] ?? "" },
            set: { raw[key] = $0; dirty = true }
        )
    }

    private func load() async {
        isLoading = true; errorMessage = nil; defer { isLoading = false }
        do {
            let settings = try await SettingsAdminService.shared.listSettings()
            var dict: [String: String] = [:]
            for s in settings { dict[s.key] = s.value ?? "" }
            // Pre-populate known keys with empty value so user can fill in
            for group in groups {
                for field in group.fields {
                    if dict[field.key] == nil { dict[field.key] = "" }
                }
            }
            raw = dict
            dirty = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        errorMessage = nil; successMessage = nil
        isSaving = true; defer { isSaving = false }
        let entries = raw.map { AdminSetting(key: $0.key, value: $0.value) }
        do {
            try await SettingsAdminService.shared.updateSettings(entries)
            successMessage = "Paramètres sauvegardés."
            dirty = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

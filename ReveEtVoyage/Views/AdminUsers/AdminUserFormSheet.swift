import SwiftUI

struct AdminUserFormSheet: View {
    enum Mode {
        case create
        case edit(AdminUser)
    }

    let mode: Mode
    let onSaved: (AdminUser) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var prenom: String = ""
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var role: String = "customer"
    @State private var password: String = ""
    @State private var phone: String = ""
    @State private var adresse: String = ""
    @State private var codePostal: String = ""
    @State private var ville: String = ""
    @State private var pays: String = "Belgique"
    @State private var language: String = "fr"

    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    private let roleOptions: [(value: String, label: String)] = [
        ("customer", "Client"),
        ("moderator", "Modérateur"),
        ("admin", "Administrateur"),
    ]

    private let languageOptions: [(value: String, label: String)] = [
        ("fr", "Français"),
        ("en", "English"),
        ("nl", "Nederlands"),
    ]

    var body: some View {
        NavigationView {
            Form {
                Section("Identité") {
                    TextField("Prénom", text: $prenom).autocapitalization(.words)
                    TextField("Nom *", text: $name).autocapitalization(.words)
                    TextField("Email *", text: $email).keyboardType(.emailAddress).autocapitalization(.none)
                }
                Section("Rôle") {
                    Picker("Rôle", selection: $role) {
                        ForEach(roleOptions, id: \.value) { Text($0.label).tag($0.value) }
                    }
                    .pickerStyle(.menu)
                }
                Section(passwordSectionTitle) {
                    SecureField(isCreate ? "Mot de passe (8+ caractères) *" : "Laisser vide pour ne pas changer", text: $password)
                }
                Section("Coordonnées") {
                    TextField("Téléphone", text: $phone).keyboardType(.phonePad)
                    TextField("Adresse", text: $adresse)
                    HStack {
                        TextField("CP", text: $codePostal).frame(maxWidth: 90)
                        TextField("Ville", text: $ville)
                    }
                    TextField("Pays", text: $pays)
                    Picker("Langue", selection: $language) {
                        ForEach(languageOptions, id: \.value) { Text($0.label).tag($0.value) }
                    }
                    .pickerStyle(.menu)
                }
                if let err = errorMessage {
                    Section {
                        Text(err).font(.system(size: 13)).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(isCreate ? "Nouvel utilisateur" : "Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView().tint(.revOrange) }
                        else { Text("Enregistrer").fontWeight(.semibold).foregroundColor(.revOrange) }
                    }
                    .disabled(isSaving || !canSave)
                }
            }
            .onAppear(perform: preload)
        }
    }

    private var isCreate: Bool { if case .create = mode { return true } else { return false } }

    private var passwordSectionTitle: String {
        isCreate ? "Mot de passe *" : "Mot de passe (optionnel)"
    }

    private var canSave: Bool {
        let baseOK = !name.trimmingCharacters(in: .whitespaces).isEmpty
            && email.contains("@") && email.contains(".")
        if isCreate { return baseOK && password.count >= 8 }
        return baseOK
    }

    private func preload() {
        guard case .edit(let u) = mode else { return }
        prenom = u.prenom ?? ""
        name = u.name
        email = u.email
        role = u.role
        phone = u.phone ?? ""
        adresse = u.adresse ?? ""
        codePostal = u.code_postal ?? ""
        ville = u.ville ?? ""
        pays = u.pays ?? "Belgique"
        language = u.language ?? "fr"
    }

    private func save() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        let payload = AdminUserPayload(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            prenom: prenom.isEmpty ? nil : prenom,
            email: email.trimmingCharacters(in: .whitespaces).lowercased(),
            role: role,
            password: password.isEmpty ? nil : password,
            phone: phone.isEmpty ? nil : phone,
            adresse: adresse.isEmpty ? nil : adresse,
            code_postal: codePostal.isEmpty ? nil : codePostal,
            ville: ville.isEmpty ? nil : ville,
            pays: pays.isEmpty ? nil : pays,
            language: language
        )

        do {
            let saved: AdminUser
            switch mode {
            case .create:
                saved = try await UserAdminService.shared.create(payload: payload)
            case .edit(let u):
                saved = try await UserAdminService.shared.update(id: u.id, payload: payload)
            }
            onSaved(saved)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

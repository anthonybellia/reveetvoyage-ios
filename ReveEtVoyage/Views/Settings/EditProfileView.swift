import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var prenom: String = ""
    @State private var nom: String = ""
    @State private var phone: String = ""
    @State private var dateNaissance: Date = Date()
    @State private var hasDateNaissance: Bool = false
    @State private var nationalite: String = ""
    @State private var adresse: String = ""
    @State private var codePostal: String = ""
    @State private var ville: String = ""
    @State private var pays: String = ""

    @State private var saving: Bool = false
    @State private var saveError: String?

    @State private var photoItem: PhotosPickerItem? = nil
    @State private var uploadingAvatar: Bool = false
    @State private var avatarError: String?

    var body: some View {
        NavigationStack {
            Form {
                avatarSection
                Section("Identité") {
                    TextField("Prénom", text: $prenom)
                        .textContentType(.givenName)
                    TextField("Nom", text: $nom)
                        .textContentType(.familyName)
                    TextField("Téléphone", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    Toggle("Date de naissance", isOn: $hasDateNaissance.animation())
                    if hasDateNaissance {
                        DatePicker("Né(e) le", selection: $dateNaissance, displayedComponents: .date)
                    }
                    TextField("Nationalité", text: $nationalite)
                }

                Section("Adresse") {
                    TextField("Adresse", text: $adresse)
                    HStack {
                        TextField("Code postal", text: $codePostal)
                            .frame(maxWidth: 100)
                            .keyboardType(.numberPad)
                        TextField("Ville", text: $ville)
                    }
                    TextField("Pays", text: $pays)
                }

                if let saveError {
                    Section {
                        Text(saveError)
                            .font(.caption)
                            .foregroundColor(.revRed)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(colors: [Color.revYellow.opacity(0.06), Color.revBackground],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .navigationTitle("Mes informations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if saving {
                            ProgressView().tint(.revOrange)
                        } else {
                            Text("Enregistrer").bold()
                        }
                    }
                    .disabled(saving || prenom.isEmpty || nom.isEmpty)
                }
            }
            .onAppear { hydrate() }
            .onChange(of: photoItem) { newItem in
                guard let newItem else { return }
                Task { await handlePhotoSelection(newItem) }
            }
        }
    }

    @ViewBuilder
    private var avatarSection: some View {
        Section {
            HStack(spacing: 18) {
                AvatarView(
                    firstName: authService.currentUser?.prenom ?? "",
                    lastName: authService.currentUser?.nom ?? "",
                    avatarPath: authService.currentUser?.avatar,
                    size: 70
                )
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.revOrange)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.revBackground, lineWidth: 2))
                }

                VStack(alignment: .leading, spacing: 4) {
                    if uploadingAvatar {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.8)
                            Text("Upload en cours…")
                                .font(.caption)
                                .foregroundColor(.revTextSecondary)
                        }
                    } else {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Text("Changer ma photo")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.revOrange)
                        }
                        Text("Compression auto en WebP")
                            .font(.system(size: 11))
                            .foregroundColor(.revTextSecondary)
                    }
                    if let avatarError {
                        Text(avatarError)
                            .font(.caption)
                            .foregroundColor(.revRed)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 6)
        }
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem) async {
        avatarError = nil
        uploadingAvatar = true
        defer { uploadingAvatar = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data) else {
                avatarError = "Image illisible"
                return
            }
            guard let prepared = AvatarUploadService.prepareImageForUpload(uiImage) else {
                avatarError = "Compression échouée"
                return
            }
            let updatedUser = try await AvatarUploadService.shared.uploadAvatar(imageData: prepared)
            authService.currentUser = updatedUser
        } catch {
            avatarError = error.localizedDescription
        }
    }

    private func hydrate() {
        guard let user = authService.currentUser else { return }
        prenom = user.prenom
        nom = user.nom
        phone = user.phone ?? ""
        nationalite = user.nationalite ?? ""
        adresse = user.adresse ?? ""
        codePostal = user.code_postal ?? ""
        ville = user.ville ?? ""
        pays = user.pays ?? ""
        if let str = user.date_naissance, let d = str.toDate() {
            dateNaissance = d
            hasDateNaissance = true
        }
    }

    private func save() async {
        saving = true
        saveError = nil
        defer { saving = false }

        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "en_US_POSIX")
        dateFmt.dateFormat = "yyyy-MM-dd"

        let req = UpdateProfileRequest(
            prenom: prenom,
            nom: nom,
            phone: phone.isEmpty ? nil : phone,
            date_naissance: hasDateNaissance ? dateFmt.string(from: dateNaissance) : nil,
            nationalite: nationalite.isEmpty ? nil : nationalite,
            adresse: adresse.isEmpty ? nil : adresse,
            code_postal: codePostal.isEmpty ? nil : codePostal,
            ville: ville.isEmpty ? nil : ville,
            pays: pays.isEmpty ? nil : pays
        )

        if await authService.updateProfile(req) {
            dismiss()
        } else {
            saveError = authService.errorMessage ?? "Erreur lors de la sauvegarde"
        }
    }
}

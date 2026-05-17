import SwiftUI

struct AdminEmailTemplatesView: View {
    @State private var templates: [AdminEmailTemplate] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var editing: AdminEmailTemplate? = nil

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.revYellow.opacity(0.08), Color.revBackground],
                           startPoint: .top, endPoint: .center).ignoresSafeArea()
            content
        }
        .navigationTitle("Templates emails")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $editing) { t in
            EmailTemplateFormSheet(template: t) { updated in
                if let i = templates.firstIndex(where: { $0.id == updated.id }) {
                    templates[i] = updated
                }
            }
        }
        .task { if templates.isEmpty { await load() } }
        .refreshable { await load() }
    }

    @ViewBuilder private var content: some View {
        if isLoading && templates.isEmpty {
            LoadingView()
        } else if let err = errorMessage, templates.isEmpty {
            ErrorView(message: err) { Task { await load() } }
        } else if templates.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "envelope.open").font(.system(size: 48)).foregroundColor(.revOrange.opacity(0.4))
                Text("Aucun template").foregroundColor(.revTextSecondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(templates) { t in
                        GlassCard(padding: 12) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10).fill(Color.revOrange.opacity(0.14))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "envelope.fill").foregroundColor(.revOrange)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(t.nom).font(.system(size: 14, weight: .semibold)).foregroundColor(.revText)
                                    if let s = t.sujet, !s.isEmpty {
                                        Text(s).font(.system(size: 11)).foregroundColor(.revTextSecondary).lineLimit(1)
                                    }
                                    Text(t.key).font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.revTextSecondary.opacity(0.7))
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.revTextSecondary)
                            }
                        }
                        .onTapGesture { editing = t }
                    }
                }.padding(.horizontal, 14).padding(.vertical, 8)
            }
        }
    }

    private func load() async {
        isLoading = true; errorMessage = nil; defer { isLoading = false }
        do { templates = try await SettingsAdminService.shared.listTemplates() }
        catch { errorMessage = error.localizedDescription }
    }
}

struct EmailTemplateFormSheet: View {
    let template: AdminEmailTemplate
    let onSaved: (AdminEmailTemplate) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var sujet: String = ""
    @State private var contenu: String = ""
    @State private var testEmail: String = ""
    @State private var isSaving: Bool = false
    @State private var isSendingTest: Bool = false
    @State private var errorMessage: String? = nil
    @State private var infoMessage: String? = nil

    var body: some View {
        NavigationView {
            Form {
                Section("Sujet") {
                    TextField("Sujet de l'email", text: $sujet)
                }
                Section("Contenu (HTML)") {
                    TextEditor(text: $contenu).frame(minHeight: 220).font(.system(size: 13))
                }
                if let vars = template.variables, !vars.isEmpty {
                    Section("Variables disponibles") {
                        Text(vars).font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.revTextSecondary)
                    }
                }
                Section("Envoyer un test") {
                    TextField("destinataire@example.com", text: $testEmail)
                        .keyboardType(.emailAddress).autocapitalization(.none)
                    Button {
                        Task { await sendTest() }
                    } label: {
                        HStack {
                            if isSendingTest { ProgressView().tint(.revOrange) }
                            else { Image(systemName: "paperplane.fill").foregroundColor(.revOrange) }
                            Text("Envoyer un test").foregroundColor(.revOrange)
                        }
                    }
                    .disabled(isSendingTest || !testEmail.contains("@"))
                }
                if let err = errorMessage {
                    Section { Text(err).foregroundColor(.red).font(.system(size: 13)) }
                }
                if let info = infoMessage {
                    Section { Text(info).foregroundColor(.green).font(.system(size: 13)) }
                }
            }
            .navigationTitle(template.nom)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView().tint(.revOrange) }
                        else { Text("Enregistrer").fontWeight(.semibold).foregroundColor(.revOrange) }
                    }
                    .disabled(isSaving || contenu.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                sujet = template.sujet ?? ""
                contenu = template.contenu ?? ""
            }
        }
    }

    private func save() async {
        errorMessage = nil; infoMessage = nil
        isSaving = true; defer { isSaving = false }
        do {
            let saved = try await SettingsAdminService.shared.updateTemplate(
                id: template.id, sujet: sujet.isEmpty ? nil : sujet, contenu: contenu
            )
            onSaved(saved)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sendTest() async {
        errorMessage = nil; infoMessage = nil
        isSendingTest = true; defer { isSendingTest = false }
        do {
            try await SettingsAdminService.shared.sendTestTemplate(id: template.id, to: testEmail)
            infoMessage = "Email de test envoyé à \(testEmail)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

import SwiftUI

struct ParticipantsView: View {
    @ObservedObject var viewModel: ExpensesViewModel

    @State private var showAddGuest = false
    @State private var showInviteEmail = false
    @State private var participantToDelete: ExpenseParticipant?

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.participants.isEmpty {
                LoadingView()
            } else if let error = viewModel.errorMessage, viewModel.participants.isEmpty {
                ErrorView(message: error) { Task { await viewModel.refresh() } }
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        participantsList
                        actionButtons
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .refreshable { await viewModel.refresh() }
            }
        }
        .sheet(isPresented: $showAddGuest) {
            AddGuestSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showInviteEmail) {
            InviteEmailSheet(viewModel: viewModel)
        }
        .confirmationDialog(
            "Retirer ce participant ?",
            isPresented: Binding(
                get: { participantToDelete != nil },
                set: { if !$0 { participantToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let p = participantToDelete {
                Button("Retirer \(p.display_name)", role: .destructive) {
                    Task { await viewModel.removeParticipant(p) }
                    participantToDelete = nil
                }
                Button("Annuler", role: .cancel) { participantToDelete = nil }
            }
        } message: {
            Text("Les dépenses existantes ne seront pas supprimées.")
        }
    }

    // MARK: - Sections

    private var participantsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(
                title: "Participants",
                systemImage: "person.2.fill",
                trailing: "\(viewModel.participants.count)"
            )
            .padding(.horizontal, 4)

            if viewModel.participants.isEmpty {
                GlassCard {
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 32))
                            .foregroundColor(.revTextSecondary)
                        Text("Aucun participant.")
                            .font(.system(size: 14))
                            .foregroundColor(.revTextSecondary)
                        Text("Ajoute un invité ou invite par email.")
                            .font(.system(size: 12))
                            .foregroundColor(.revTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            } else {
                ForEach(viewModel.participants) { participant in
                    ParticipantRow(
                        participant: participant,
                        onRemove: { participantToDelete = participant }
                    )
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            BrandButton(
                title: "Ajouter un invité",
                systemImage: "person.crop.circle.badge.plus"
            ) {
                showAddGuest = true
            }

            BrandButton(
                title: "Inviter par email",
                systemImage: "envelope.fill",
                style: .secondary
            ) {
                showInviteEmail = true
            }
        }
    }
}

// MARK: - Participant row

private struct ParticipantRow: View {
    let participant: ExpenseParticipant
    let onRemove: () -> Void

    var body: some View {
        GlassCard(padding: 14) {
            HStack(spacing: 12) {
                AvatarView(
                    firstName: participant.display_name.split(separator: " ").first.map(String.init) ?? participant.display_name,
                    lastName: participant.display_name.split(separator: " ").dropFirst().first.map(String.init) ?? "",
                    avatarPath: participant.avatar_url,
                    size: 40
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(participant.display_name)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.revText)

                    HStack(spacing: 4) {
                        Image(systemName: participant.is_guest ? "person.fill.questionmark" : "checkmark.seal.fill")
                            .font(.system(size: 10))
                        Text(participant.is_guest ? "Invité" : "Membre")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(participant.is_guest ? .revTextSecondary : .revOrange)
                }

                Spacer()

                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.revRed)
                        .padding(8)
                        .background(Circle().fill(Color.revRed.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map { String($0) } ?? ""
        let last = parts.dropFirst().first?.first.map { String($0) } ?? ""
        let result = (first + last).uppercased()
        return result.isEmpty ? "?" : result
    }
}

// MARK: - Add guest sheet

private struct AddGuestSheet: View {
    @ObservedObject var viewModel: ExpensesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var isSaving: Bool = false
    @State private var localError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.revBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        GlassCard(padding: 14) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("NOM DE L'INVITÉ")
                                        .font(.system(size: 11, weight: .bold))
                                        .tracking(0.5)
                                }
                                .foregroundColor(.revOrange)

                                TextField("Ex : Marie Dubois", text: $name)
                                    .font(.system(size: 16, design: .rounded))
                                    .textInputAutocapitalization(.words)
                            }
                        }

                        Text("L'invité pourra apparaître dans les dépenses sans avoir de compte.")
                            .font(.system(size: 12))
                            .foregroundColor(.revTextSecondary)
                            .multilineTextAlignment(.center)

                        if let err = localError {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundColor(.revError)
                                .multilineTextAlignment(.center)
                        }

                        BrandButton(
                            title: "Ajouter",
                            systemImage: "checkmark.circle.fill",
                            isLoading: isSaving
                        ) {
                            Task { await save() }
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                        .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.55 : 1)
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Ajouter un invité")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundColor(.revBrown)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        localError = nil
        defer { isSaving = false }

        if await viewModel.addParticipant(displayName: trimmed) {
            dismiss()
        } else {
            localError = viewModel.errorMessage ?? "Une erreur est survenue"
        }
    }
}

// MARK: - Invite email sheet

private struct InviteEmailSheet: View {
    @ObservedObject var viewModel: ExpensesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var isSaving: Bool = false
    @State private var localError: String?

    private var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.revBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        GlassCard(padding: 14) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    Image(systemName: "envelope.fill")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("EMAIL")
                                        .font(.system(size: 11, weight: .bold))
                                        .tracking(0.5)
                                }
                                .foregroundColor(.revOrange)

                                TextField("ami@example.com", text: $email)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .font(.system(size: 16, design: .rounded))
                            }
                        }

                        Text("Si la personne a un compte Rêve Et Voyage, elle sera ajoutée comme membre. Sinon, un invité est créé en attendant qu'elle s'inscrive.")
                            .font(.system(size: 12))
                            .foregroundColor(.revTextSecondary)
                            .multilineTextAlignment(.center)

                        if let err = localError {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundColor(.revError)
                                .multilineTextAlignment(.center)
                        }

                        BrandButton(
                            title: "Inviter",
                            systemImage: "paperplane.fill",
                            isLoading: isSaving
                        ) {
                            Task { await save() }
                        }
                        .disabled(!isEmailValid || isSaving)
                        .opacity(isEmailValid ? 1 : 0.55)
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Inviter par email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .foregroundColor(.revBrown)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isEmailValid else { return }
        isSaving = true
        localError = nil
        defer { isSaving = false }

        if await viewModel.addParticipant(email: trimmed) {
            dismiss()
        } else {
            localError = viewModel.errorMessage ?? "Une erreur est survenue"
        }
    }
}

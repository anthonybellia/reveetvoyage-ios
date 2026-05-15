import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Binding var showRegister: Bool
    @FocusState private var focusedField: Field?

    @State private var iconScale: CGFloat = 0.7
    @State private var iconOpacity: Double = 0
    @State private var iconBreath: CGFloat = 1
    @State private var titleOffset: CGFloat = 20
    @State private var titleOpacity: Double = 0
    @State private var emailOffset: CGFloat = 30
    @State private var emailOpacity: Double = 0
    @State private var passwordOffset: CGFloat = 30
    @State private var passwordOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 30
    @State private var buttonOpacity: Double = 0
    @State private var footerOpacity: Double = 0
    @State private var buttonPressed: Bool = false
    @State private var errorShake: CGFloat = 0

    enum Field: Hashable { case email, password }

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    iconHeader
                        .padding(.top, 50)
                        .padding(.bottom, 32)

                    titleBlock
                        .padding(.bottom, 32)

                    formCard
                        .padding(.horizontal, 24)

                    footerSection
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear { runEntranceAnimations() }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            if newValue != nil { triggerErrorShake() }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.revYellow.opacity(0.18),
                Color.revOrange.opacity(0.12),
                Color.revBackground
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Icon header (rappel de la marque)

    private var iconHeader: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.revYellow.opacity(0.35),
                            Color.revOrange.opacity(0.15),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 110
                    )
                )
                .frame(width: 220, height: 220)
                .blur(radius: 6)

            Image("Icon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 130, height: 130)
                .scaleEffect(iconScale * iconBreath)
                .opacity(iconOpacity)
                .shadow(color: Color.revOrange.opacity(0.25), radius: 18, x: 0, y: 8)
        }
    }

    // MARK: - Title

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text("Bon retour !")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.revBrown, .revRed],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .offset(y: titleOffset)
                .opacity(titleOpacity)

            Text("Connecte-toi pour continuer ton voyage")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.revTextSecondary)
                .multilineTextAlignment(.center)
                .opacity(titleOpacity * 0.8)
        }
    }

    // MARK: - Form

    private var formCard: some View {
        VStack(spacing: 16) {
            inputField(
                icon: "envelope.fill",
                placeholder: "Email",
                text: $viewModel.email,
                isSecure: false,
                field: .email
            )
            .offset(x: errorShake, y: emailOffset)
            .opacity(emailOpacity)

            inputField(
                icon: "lock.fill",
                placeholder: "Mot de passe",
                text: $viewModel.password,
                isSecure: true,
                field: .password
            )
            .offset(x: errorShake, y: passwordOffset)
            .opacity(passwordOpacity)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.revRed)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            connectButton
                .offset(y: buttonOffset)
                .opacity(buttonOpacity)
                .padding(.top, 4)
        }
    }

    private func inputField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool,
        field: Field
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(focusedField == field ? .revOrange : .revTextSecondary)
                .frame(width: 22)
                .animation(.easeInOut(duration: 0.2), value: focusedField)

            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                        .textContentType(.password)
                } else {
                    TextField(placeholder, text: text)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
            .font(.system(size: 16, weight: .regular, design: .rounded))
            .foregroundColor(.revText)
            .focused($focusedField, equals: field)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.revCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    focusedField == field
                        ? Color.revOrange.opacity(0.6)
                        : Color.gray.opacity(0.15),
                    lineWidth: focusedField == field ? 1.5 : 1
                )
        )
        .animation(.easeInOut(duration: 0.2), value: focusedField)
    }

    private var connectButton: some View {
        Button {
            focusedField = nil
            Task { await viewModel.login() }
        } label: {
            ZStack {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Se connecter")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.revOrange, Color.revRed],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(
                color: Color.revOrange.opacity(buttonPressed ? 0.15 : 0.35),
                radius: buttonPressed ? 6 : 14,
                x: 0,
                y: buttonPressed ? 3 : 8
            )
            .scaleEffect(buttonPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: buttonPressed)
        }
        .disabled(viewModel.isLoading)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in buttonPressed = true }
                .onEnded { _ in buttonPressed = false }
        )
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 18) {
            HStack(spacing: 10) {
                Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.2))
                Text("ou").font(.caption).foregroundColor(.revTextSecondary)
                Rectangle().frame(height: 1).foregroundColor(.gray.opacity(0.2))
            }
            .padding(.horizontal, 40)

            Button {
                withAnimation(.easeInOut(duration: 0.4)) {
                    showRegister = true
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Pas encore inscrit ?")
                        .foregroundColor(.revTextSecondary)
                    Text("Créer un compte")
                        .foregroundColor(.revRed)
                        .fontWeight(.semibold)
                }
                .font(.system(size: 14, weight: .medium, design: .rounded))
            }
        }
        .opacity(footerOpacity)
    }

    // MARK: - Animations

    private func runEntranceAnimations() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.65).delay(0.05)) {
            iconScale = 1
            iconOpacity = 1
        }

        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(0.8)) {
            iconBreath = 1.06
        }

        withAnimation(.easeOut(duration: 0.5).delay(0.25)) {
            titleOffset = 0
            titleOpacity = 1
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.4)) {
            emailOffset = 0
            emailOpacity = 1
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.5)) {
            passwordOffset = 0
            passwordOpacity = 1
        }

        withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.6)) {
            buttonOffset = 0
            buttonOpacity = 1
        }

        withAnimation(.easeIn(duration: 0.4).delay(0.75)) {
            footerOpacity = 1
        }
    }

    private func triggerErrorShake() {
        let baseAnim = Animation.spring(response: 0.18, dampingFraction: 0.4)
        withAnimation(baseAnim) { errorShake = -10 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(baseAnim) { errorShake = 10 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(baseAnim) { errorShake = -6 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(baseAnim) { errorShake = 0 }
        }
    }
}

#Preview {
    LoginView(showRegister: .constant(false))
}

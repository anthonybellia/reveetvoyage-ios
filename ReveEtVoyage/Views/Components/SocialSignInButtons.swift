import AuthenticationServices
import SwiftUI

/// Native Apple Sign-In button wrapped for SwiftUI — required look-and-feel for App Store review.
struct AppleSignInButton: UIViewRepresentable {
    let onTap: () -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(
            authorizationButtonType: .continue,
            authorizationButtonStyle: .black
        )
        button.cornerRadius = 14
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    final class Coordinator: NSObject {
        let onTap: () -> Void
        init(onTap: @escaping () -> Void) { self.onTap = onTap }
        @objc func tapped() { onTap() }
    }
}

/// Google-branded "Continue with Google" button (white background, neutral grey border, G letter mark).
struct GoogleSignInButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.white)
                    Text("G")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.26, green: 0.52, blue: 0.96),
                                    Color(red: 0.92, green: 0.26, blue: 0.21),
                                    Color(red: 0.98, green: 0.74, blue: 0.02),
                                    Color(red: 0.20, green: 0.66, blue: 0.33)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .frame(width: 22, height: 22)

                Text("Continuer avec Google")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(red: 0.13, green: 0.13, blue: 0.13))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(red: 0.85, green: 0.85, blue: 0.85), lineWidth: 1)
            )
        }
    }
}

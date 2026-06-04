import SwiftUI

/// Full-screen celebratory overlay shown when every étape of a voyage is
/// marked complete. Shown once per voyage (UserDefaults keyed).
struct TripCompletedOverlay: View {
    let voyage: Voyage
    let onClose: () -> Void
    let onNewTrip: () -> Void

    @State private var cardScale: CGFloat = 0.7
    @State private var cardOpacity: Double = 0
    @State private var confettiBurst: Int = 0
    @State private var headerFloat: CGFloat = 0

    var body: some View {
        ZStack {
            // Dimmed gradient background
            LinearGradient(
                colors: [
                    Color.revBrownDark.opacity(0.92),
                    Color.revRed.opacity(0.88),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .transition(.opacity)

            // Confetti
            CelebrationOverlay(burst: confettiBurst)
                .allowsHitTesting(false)

            // Card
            VStack(spacing: 22) {
                Image(systemName: "airplane.circle.fill")
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.revYellow, .white],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .offset(y: headerFloat)
                    .shadow(color: .white.opacity(0.4), radius: 16)

                VStack(spacing: 10) {
                    Text("Voyage terminé !")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Tu as vécu \(voyage.titre).")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)

                    Text("On espère que c'était à la hauteur. Prêt·e pour la prochaine aventure ?")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                        .padding(.horizontal, 8)
                }

                VStack(spacing: 10) {
                    Button(action: onNewTrip) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                            Text("Préparer le prochain voyage")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.revRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white)
                        )
                        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
                    }

                    Button(action: onClose) {
                        Text("Plus tard")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.vertical, 8)
                    }
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 28)
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
        }
        .onAppear { animateIn() }
    }

    private func animateIn() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.1)) {
            cardScale = 1.0
            cardOpacity = 1.0
        }
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            headerFloat = -6
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        confettiBurst += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            confettiBurst += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            confettiBurst += 1
        }
    }
}

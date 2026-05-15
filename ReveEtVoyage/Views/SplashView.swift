import SwiftUI

struct SplashView: View {
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var titleOffset: CGFloat = 30
    @State private var titleOpacity: Double = 0
    @State private var dotsRotation: Double = 0
    @State private var gradientShift: CGFloat = 0

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            orbitingDots

            Image("Icon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        }
        .onAppear { startAnimations() }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.revYellow.opacity(0.35),
                Color.revOrange.opacity(0.45),
                Color.revRed.opacity(0.30)
            ],
            startPoint: UnitPoint(x: 0, y: gradientShift),
            endPoint: UnitPoint(x: 1, y: 1 - gradientShift)
        )
        .animation(
            .easeInOut(duration: 4).repeatForever(autoreverses: true),
            value: gradientShift
        )
    }

    private var orbitingDots: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Circle()
                    .fill(dotColor(for: i))
                    .frame(width: dotSize(for: i), height: dotSize(for: i))
                    .offset(y: -130)
                    .rotationEffect(.degrees(Double(i) * 45 + dotsRotation))
                    .opacity(iconOpacity * 0.8)
            }
        }
    }

    private func dotColor(for index: Int) -> Color {
        let palette: [Color] = [.revYellow, .revOrange, .revRed]
        return palette[index % palette.count]
    }

    private func dotSize(for index: Int) -> CGFloat {
        index.isMultiple(of: 2) ? 10 : 6
    }

    private func startAnimations() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.1)) {
            iconScale = 1
            iconOpacity = 1
        }

        withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
            titleOffset = 0
            titleOpacity = 1
        }

        withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
            dotsRotation = 360
        }

        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            gradientShift = 1
        }
    }
}

#Preview {
    SplashView()
}

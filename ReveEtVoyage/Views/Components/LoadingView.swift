import SwiftUI

struct LoadingView: View {
    var message: String = "Chargement…"

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.revOrange)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.revTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
